# 🚀 Reverse SSH Tunnel Auto Script by Moriistar

یک اسکریپت خودکار و ساده برای ایجاد تانل Reverse SSH بین دو سرور (ایران و خارج) با مدیریت سرویس‌های Systemd.

این اسکریپت تمام مراحل پیچیده مثل ساخت کلید SSH، تنظیم `sshd_config` و ساخت سرویس‌ها را به صورت اتوماتیک انجام می‌دهد.

## 📥 نصب و اجرا (Installation)

در هر دو سرور (ایران و خارج) کافیست فقط دستور زیر را اجرا کنید تا منوی مدیریت نمایش داده شود:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Moriistar/tunellreverseSSH/main/install.sh)
