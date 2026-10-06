# SakuSiswa — HTML + CSS + JavaScript + Supabase

Aplikasi tabungan siswa dalam bahasa Indonesia, tanpa framework atau proses build. Kode dapat disimpan di GitHub dan frontend ditayangkan melalui GitHub Pages. Data dan login menggunakan proyek Supabase milik Anda.

## Isi paket

- `index.html`: halaman login dan dashboard aplikasi.
- `assets/style.css`: tampilan responsif desktop dan ponsel.
- `assets/app.js`: login, dashboard, formulir, impor/ekspor, dan integrasi Supabase.
- `assets/core.js`: perhitungan saldo, CSV, pengamanan tampilan, dan waktu WIB.
- `config.js`: konfigurasi Supabase dan identitas sekolah.
- `supabase/schema.sql`: tabel, indeks, hak akses RLS, dan fungsi transaksi.
- `supabase/admin-pertama.sql`: registrasi admin awal.
- `templates/template-siswa.csv`: template kosong untuk impor.
- `templates/contoh-siswa.csv`: dua baris contoh; bukan data siswa asli.
- `tests/core.test.cjs`: tes JavaScript dengan Node.js.
- `tests/render.test.cjs`: tes perenderan login, dashboard, dan formulir tanpa browser.
- `tests/rls.integration.sql`: tes hak akses dan database untuk dijalankan di Supabase.
- `PANDUAN-CEPAT.html`: panduan pemasangan yang dapat dibuka di browser.

## 1. Buat dan siapkan Supabase

1. Buat proyek Supabase baru. Jangan menjalankan schema ini pada database yang memiliki tabel `profiles`, `students`, atau `transactions` dengan struktur lain.
2. Di SQL Editor, jalankan seluruh isi `supabase/schema.sql` satu kali. Skrip dijalankan dalam transaksi; error akan membatalkan pemasangan.
3. Di Authentication, aktifkan provider Email dan email confirmation. Aktivasi akun di website memakai sign-up email/password; karena itu jangan menonaktifkan sign-up.
4. Admin/wali kelas mendaftarkan email yang boleh mengakses data pada tabel profil melalui aplikasi. Orang yang sekadar sign-up tanpa terdaftar tidak mendapat akses data.
5. Siapkan pengiriman email Supabase/SMTP untuk email konfirmasi dan reset password sebelum digunakan oleh siswa.

## 2. Hubungkan konfigurasi

Edit `config.js`:

```js
window.APP_CONFIG = {
  supabaseUrl: 'https://PROJECT-ANDA.supabase.co',
  supabaseKey: 'PUBLISHABLE-ATAU-ANON-KEY-ANDA',
  schoolName: 'SMP Negeri Contoh',
  schoolYear: '2026 / 2027'
};
```

Ambil Project URL dan publishable/anon key dari dashboard proyek. Jangan gunakan secret key, service_role key, atau password database di frontend maupun repository GitHub. Tidak ada service_role key yang diperlukan oleh aplikasi ini.

## 3. Buat admin pertama

1. Edit email dan nama dalam `supabase/admin-pertama.sql` lalu jalankan melalui SQL Editor.
2. Buka website, pilih **Aktivasi akun baru**, dan gunakan email admin yang sama beserta password minimal delapan karakter.
3. Konfirmasi email, lalu masuk melalui halaman login.
4. Tidak ada mekanisme otomatis yang menjadikan pengunjung pertama sebagai admin.

Untuk menambah admin berikutnya, admin yang sudah aktif menggunakan menu Pengguna. Role tidak diambil dari pilihan pengguna saat login atau metadata sign-up.

## 4. Upload ke GitHub dan aktifkan GitHub Pages

1. Ekstrak ZIP. Upload **isi folder `saku-siswa-supabase`** ke root repository GitHub; `index.html` harus berada di root.
2. Buka Settings → Pages, gunakan sumber **Deploy from a branch**, pilih branch `main` dan folder `/ (root)`, lalu simpan.
3. Tunggu GitHub Pages aktif, lalu buka URL yang diberikan GitHub. Untuk repository proyek, URL umumnya `https://USERNAME.github.io/NAMA-REPOSITORY/`.
4. Di Supabase Authentication → URL Configuration, isi **Site URL** dengan URL GitHub Pages tersebut, termasuk nama repository dan trailing slash.
5. Tambahkan URL yang sama pada **Redirect URLs**, serta alamat lokal jika digunakan, misalnya `http://localhost:8080/`.
6. Reload website setelah menyimpan konfigurasi.

Seluruh jalur asset dibuat relatif agar dapat berjalan di subfolder repository GitHub Pages. Website tidak membutuhkan Node.js untuk dijalankan. Koneksi internet diperlukan untuk Supabase dan SDK dari jsDelivr.

## 5. Alur penggunaan

### Admin

- Tambahkan akun wali kelas/admin pada menu Pengguna dengan nama, email, peran, dan kelas.
- Kelola semua siswa dan seluruh transaksi; admin dapat memilih wali kelas untuk siswa baru/impor dan mengubah penugasannya melalui Edit siswa.
- Nonaktifkan/aktifkan kembali akun melalui Pengguna. Akun nonaktif kehilangan akses data, termasuk saat token login lama masih ada.
- Batalkan transaksi yang salah dengan alasan. Pembatalan mempertahankan jejak audit. Setoran tidak dapat dibatalkan jika menghasilkan saldo negatif.
- Kesalahan jumlah/tanggal dikoreksi dengan membatalkan transaksi kemudian mencatat transaksi pengganti.

### Wali kelas

- Aktivasi akun dengan email yang telah didaftarkan admin, konfirmasi email, lalu login.
- Tambahkan siswa satu per satu atau impor CSV. Siswa yang dibuat wali kelas otomatis ditugaskan kepada wali kelas tersebut; parameter wali kelas yang dimanipulasi di browser diabaikan database.
- Edit nama, NIS, dan kelas siswa yang menjadi tanggung jawabnya.
- Pilih siswa, tanggal, waktu WIB, dan jumlah untuk mencatat setoran.
- Untuk pengeluaran, pilih jenis Pengeluaran dan isi tujuan penggunaan uang. Pengeluaran tidak boleh melebihi saldo.
- Lihat rincian siswa dan ekspor data/laporan.

### Siswa

- Wali kelas mendaftarkan email siswa melalui Data siswa.
- Siswa membuka halaman login, memilih Aktivasi akun baru, membuat password dengan email tersebut, dan mengonfirmasi email.
- Siswa hanya melihat saldo dan riwayat setoran/pengeluaran miliknya. Tidak dapat menulis, meskipun mengirim permintaan API sendiri.

Email siswa sebaiknya unik dan benar-benar dapat menerima email. Jika siswa belum memiliki email, sekolah perlu menyediakan akun email individual. Website ini tidak menyediakan login NIS/password tanpa email.

## 6. Impor dan ekspor

Template memiliki empat kolom tepat dalam urutan berikut:

```csv
NIS,Nama,Kelas,Email
2026001,Aditya Pratama,VII A,aditya@sekolah.sch.id
```

- Template yang diunduh dari aplikasi hanya berisi header agar baris contoh tidak ikut terimpor.
- Gunakan UTF-8 dan pemisah **koma**. Bila Excel menghasilkan titik koma, simpan ulang sebagai CSV dengan koma.
- Maksimal 500 siswa per impor dan ukuran file maksimal 2 MB.
- NIS dan email harus unik, nama/kelas wajib diisi. NIS dibaca sebagai teks sehingga nol di depan dapat dipertahankan.
- Pratinjau ditampilkan sebelum impor. Database membuat profil dan siswa secara atomik; jika satu baris gagal, seluruh impor batal.
- Impor tidak membuat password atau mengirim undangan otomatis. Siswa tetap melakukan Aktivasi akun.
- Ekspor data siswa berisi saldo dan status; laporan berisi tanggal WIB, nama, jenis, jumlah, keterangan, pencatat, dan status pembatalan. Filter nama/siswa/jenis/tanggal berlaku pada ekspor transaksi.
- Untuk keamanan spreadsheet, nilai yang dimulai dengan karakter formula diberi tanda petik saat ekspor.

## 7. Penyimpanan dan keamanan

Data sekolah disimpan di Supabase PostgreSQL, bukan localStorage. SDK Supabase menyimpan sesi login di browser; logout setelah memakai perangkat bersama. Mode demo hanya memakai memori sesi dan tidak menulis database.

RLS membatasi SELECT berdasarkan profil aktif. Browser tidak mendapat izin INSERT/UPDATE/DELETE langsung. Penulisan hanya melalui RPC yang memeriksa role dan pemilik siswa. Perhitungan saldo dan penguncian baris siswa dilakukan di database supaya dua pengeluaran bersamaan tidak membuat saldo negatif.

Transaksi asli dan akun tidak dihapus melalui UI agar catatan historis terjaga. Admin menonaktifkan akun dan membatalkan transaksi; nama/NIS/kelas/penugasan siswa bisa diedit. Email login yang sudah didaftarkan tetap dipertahankan agar identitas riwayat konsisten. Perubahan email atau penghapusan permanen memerlukan prosedur administrasi Supabase tersendiri.

## 8. Menjalankan lokal dan tes

Di folder paket:

```bash
python3 -m http.server 8080
```

Buka `http://localhost:8080/`, bukan langsung `file://`. Untuk mencoba tanpa Supabase, klik **Coba mode demo**. Pilih peran di bar bagian atas. Beralih peran me-reset data demo.

Tes JavaScript (Node.js 18+):

```bash
node --test tests/*.cjs
```

Tes database: jalankan `tests/rls.integration.sql` dalam SQL Editor setelah memasang schema, sebaiknya pada proyek pengujian. Data uji dibatalkan dengan ROLLBACK. Jika tes error, jalankan `ROLLBACK;` sebelum menggunakan editor kembali.

Sebelas tes JavaScript telah dijalankan dan berhasil saat paket dibuat. Skrip SQL dan RLS disediakan tetapi belum diuji pada proyek Supabase Anda; pengujian login, email, RLS, dan dua transaksi bersamaan tetap perlu dilakukan setelah konfigurasi. Tampilan belum diuji melalui browser pada sesi pembuatan paket.

## Masalah umum

- **Konfigurasi belum diisi:** ubah URL/key di `config.js`, upload ulang, lalu reload.
- **Akun belum terdaftar/nonaktif:** admin/wali kelas harus mendaftarkan email yang sama; sign-up saja tidak cukup.
- **Email not confirmed:** klik tautan konfirmasi. Periksa spam dan konfigurasi pengiriman email.
- **Konfirmasi/reset kembali ke URL salah:** perbaiki Site URL dan Redirect URLs di Supabase.
- **Function/table does not exist:** pasang `schema.sql` lengkap pada proyek yang URL-nya dipakai frontend.
- **NIS/email sudah terdaftar:** hapus duplikat dari CSV atau gunakan Edit siswa untuk perubahan data.
- **Library Supabase gagal dimuat:** periksa internet dan akses ke CDN jsDelivr. Anda dapat mengunduh SDK secara lokal lalu mengganti URL script di `index.html`.

## Dokumentasi resmi

- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
