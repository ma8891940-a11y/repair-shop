-- جدولة النسخة الاحتياطية اليومية (لو ما اتجدولتش وقت تشغيل setup_all.sql).
-- قبل ما تشغّله: فعّل Cron (pg_cron) من لوحة Supabase: Integrations ← Cron.
-- آمن لو اتشغّل أكتر من مرة.
create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'warsha-daily-backup';
select cron.schedule('warsha-daily-backup', '0 1 * * *', 'select public.daily_backups()');
select jobname, schedule from cron.job where jobname = 'warsha-daily-backup';
