/* Impor Excel dan unduh template dengan kolom terpisah. */
(function(root){
function studentsFromRows(rows){
 const filled=rows.filter(r=>r.some(v=>String(v??'').trim()));
 const header=filled[0]||[];
 if(header.slice(0,4).map(v=>String(v).trim().toLowerCase()).join('|')!=='nis|nama|kelas|email'||header.slice(4).some(v=>String(v??'').trim()))throw Error('Kolom harus NIS, Nama, Kelas, Email. Gunakan template Excel yang disediakan.');
 const data=filled.slice(1);
 if(!data.length||data.length>500)throw Error('Isi 1–500 siswa pada sheet Data Siswa.');
 const result=data.map((r,i)=>{if(r.slice(4).some(v=>String(v??'').trim()))throw Error('Ada data di luar empat kolom pada baris '+(i+2)+'.');const s={nis:String(r[0]??'').trim(),name:String(r[1]??'').trim(),class_name:String(r[2]??'').trim(),email:String(r[3]??'').trim().toLowerCase()};if(!s.nis||!s.name||!s.class_name||!/^\S+@\S+\.\S+$/.test(s.email))throw Error('Lengkapi NIS, nama, kelas, dan email valid pada data ke-'+(i+1)+'.');return s});
 if(new Set(result.map(s=>s.nis)).size!==result.length||new Set(result.map(s=>s.email)).size!==result.length)throw Error('Ada NIS atau email duplikat dalam file.');
 return result;
}
async function readStudentFile(file){
 if(file.size>2*1024*1024)throw Error('Ukuran file maksimal 2 MB.');
 if(/\.csv$/i.test(file.name))return root.SakuCore.studentCSV(await file.text());
 if(!/\.xlsx$/i.test(file.name))throw Error('Gunakan file Excel .xlsx.');
 if(!root.XLSX)throw Error('Pembaca Excel belum dimuat. Periksa internet lalu refresh halaman.');
 let book;try{book=root.XLSX.read(await file.arrayBuffer(),{type:'array',cellFormula:true,sheetRows:503})}catch(e){throw Error('File Excel tidak dapat dibaca. Simpan sebagai .xlsx lalu coba lagi.')}
 const sheet=book.Sheets['Data Siswa']||book.Sheets[book.SheetNames[0]];
 if(!sheet||!sheet['!ref'])throw Error('Sheet Data Siswa kosong.');
 const range=root.XLSX.utils.decode_range(sheet['!fullref']||sheet['!ref']);
 if(range.e.r>500)throw Error('Maksimal 500 siswa. Hapus baris atau format tambahan di bawah baris 501.');
 if(range.e.c>3)throw Error('Sheet Data Siswa hanya boleh berisi empat kolom: NIS, Nama, Kelas, Email.');
 for(const [key,cell] of Object.entries(sheet)){if(!key.startsWith('!')&&(cell.f||cell.t==='e'))throw Error('Gunakan nilai teks, bukan rumus atau sel error, pada '+key+'.')}
 const rows=root.XLSX.utils.sheet_to_json(sheet,{header:1,defval:'',blankrows:false,raw:false});
 return studentsFromRows(rows);
}
function downloadTemplate(){const a=document.createElement('a');a.href='templates/template-siswa.xlsx';a.download='template-siswa.xlsx';a.click()}
root.SakuSpreadsheet={studentsFromRows,readStudentFile,downloadTemplate};
})(typeof window==='undefined'?globalThis:window);
