-- 1. ล้างตารางเดิมเพื่อปรับโครงสร้างใหม่
DROP TABLE IF EXISTS public.attendance CASCADE;
DROP TABLE IF EXISTS public.students CASCADE;
DROP TABLE IF EXISTS public.activities CASCADE;
DROP TABLE IF EXISTS public.system_users CASCADE;

-- 2. สร้างตาราง system_users
CREATE TABLE public.system_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'user')),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. สร้างตาราง activities
CREATE TABLE public.activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_code TEXT UNIQUE NOT NULL,
    activity_name TEXT NOT NULL,
    activity_date DATE NOT NULL,
    location TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'upcoming')),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. สร้างตาราง students (ลบ phone, เพิ่ม branch, room, shift)
CREATE TABLE public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT UNIQUE NOT NULL,
    prefix TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    branch TEXT NOT NULL,          -- สาขาวิชา
    class_level TEXT NOT NULL,     -- ระดับชั้น เช่น ปวช.1, ปวช.2, ปวส.1
    room TEXT NOT NULL DEFAULT '1',-- ห้อง
    shift TEXT NOT NULL CHECK (shift IN ('รอบเช้า', 'รอบบ่าย')), -- รอบเช้า / รอบบ่าย
    photo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. สร้างตาราง attendance
CREATE TABLE public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL REFERENCES public.students(student_id) ON DELETE CASCADE,
    activity_id UUID NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
    scanned_at TIMESTAMPTZ DEFAULT now(),
    scanned_by TEXT DEFAULT 'Staff',
    status TEXT NOT NULL DEFAULT 'present',
    CONSTRAINT unique_student_activity UNIQUE (student_id, activity_id)
);

-- 6. ปลดล็อกสิทธิ์ระดับ Schema และตารางให้กับ Role anon และ authenticated
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;

-- 7. เปิด RLS และสร้าง Policies แบบปลดล็อก
ALTER TABLE public.system_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_all" ON public.system_users FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "activities_all" ON public.activities FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "students_all" ON public.students FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "attendance_all" ON public.attendance FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- 8. Storage สำหรับรูปถ่าย
INSERT INTO storage.buckets (id, name, public) 
VALUES ('student-assets', 'student-assets', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "storage_all_access" ON storage.objects;
CREATE POLICY "storage_all_access" ON storage.objects FOR ALL TO anon, authenticated USING (bucket_id = 'student-assets') WITH CHECK (bucket_id = 'student-assets');

-- 9. เพิ่มข้อมูลตัวอย่างเริ่มต้น
INSERT INTO public.system_users (username, password, full_name, role) VALUES
('admin', 'admin123', 'อาจารย์ผู้ดูแลระบบ อวท.', 'admin'),
('user', 'user123', 'เจ้าหน้าที่สแกนบัตร', 'user');

INSERT INTO public.activities (activity_code, activity_name, activity_date, location, status, description) VALUES
('ACT-2569-01', 'กิจกรรมปฐมนิเทศนักศึกษาใหม่ อวท. ประจำปี 2569', CURRENT_DATE, 'หอประชุมใหญ่ วิทยาลัยเทคนิค', 'active', 'การรับฟังนโยบายและการอบรมจริยธรรมวิชาชีพ'),
('ACT-2569-02', 'ประชุมวิชาการองค์การวิชาชีพในอนาคตแห่งประเทศไทย', CURRENT_DATE + INTERVAL '5 day', 'อาคาร 5 ชั้น 3', 'upcoming', 'นำเสนอโครงงานและสิ่งประดิษฐ์คนรุ่นใหม่');

INSERT INTO public.students (student_id, prefix, first_name, last_name, branch, class_level, room, shift, photo_url) VALUES
('66209010001', 'นาย', 'สมชาย', 'สายช่าง', 'ช่างยนต์', 'ปวช. 2', '1', 'รอบเช้า', ''),
('66209010002', 'นางสาว', 'กัญญา', 'รักเรียน', 'การบัญชี', 'ปวช. 2', '1', 'รอบบ่าย', ''),
('65309010015', 'นาย', 'ธีรภัทร', 'พัฒนาระบบ', 'เทคโนโลยีสารสนเทศ', 'ปวส. 1', '2', 'รอบเช้า', ''),
('66209010045', 'นางสาว', 'มณีรัตน์', 'บริการดี', 'การโรงแรม', 'ปวช. 1', '1', 'รอบบ่าย', ''),
('65309010088', 'นาย', 'วรวิทย์', 'ไฟฟ้ากำลัง', 'ช่างไฟฟ้ากำลัง', 'ปวส. 2', '1', 'รอบเช้า', '');