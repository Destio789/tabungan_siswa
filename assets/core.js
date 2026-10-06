(function(root){
const money=n=>new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',maximumFractionDigits:0}).format(n);
const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const balance=(rows,id)=>rows.filter(t=>t.student_id===id&&!t.voided_at).reduce((n,t)=>n+(t.kind==='deposit'?Number(t.amount):-Number(t.amount)),0);
function csv(rows){return '\uFEFF'+rows.map(r=>r.map(v=>{let s=String(v??'');if(/^[=+@\-\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"'}).join(',')).join('\r\n')}
function parseCSV(text){const rows=[];let row=[],v='',q=false;text=text.replace(/^\uFEFF/,'');for(let i=0;i<text.length;i++){let c=text[i];if(c==='"'){if(q&&text[i+1]==='"'){v+='"';i++}else q=!q}else if(c===','&&!q){row.push(v);v=''}else if((c==='\n'||c==='\r')&&!q){if(c==='\r'&&text[i+1]==='\n')i++;row.push(v);if(row.some(v=>v.trim()))rows.push(row);row=[];v=''}else v+=c}if(q)throw Error('Tanda kutip CSV tidak lengkap.');row.push(v);if(row.some(v=>v.trim()))rows.push(row);return rows}
function studentCSV(text){const rows=parseCSV(text);if(rows[0]?.join(',')!=='NIS,Nama,Kelas,Email')throw Error('Kolom harus NIS,Nama,Kelas,Email. Unduh template.');const result=rows.slice(1).map(r=>({nis:r[0]?.trim(),name:r[1]?.trim(),class_name:r[2]?.trim(),email:r[3]?.trim().toLowerCase()}));if(!result.length||result.length>500)throw Error('Isi 1–500 siswa.');if(result.some(s=>!s.nis||!s.name||!s.class_name||!/^\S+@\S+\.\S+$/.test(s.email)))throw Error('Lengkapi NIS, nama, kelas, dan email valid pada setiap baris.');if(new Set(result.map(s=>s.nis)).size!==result.length||new Set(result.map(s=>s.email)).size!==result.length)throw Error('Ada NIS atau email duplikat.');return result}
function wibDate(v){return new Date(v).toLocaleString('id-ID',{timeZone:'Asia/Jakarta',day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'})+' WIB'}
function wibInput(d=new Date()){return new Date(d.getTime()+7*3600000).toISOString().slice(0,16)}
function toISO(v){if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(v))throw Error('Tanggal tidak valid.');return new Date(v+':00+07:00').toISOString()}
root.SakuCore={money,escape,balance,csv,parseCSV,studentCSV,wibDate,wibInput,toISO};
})(typeof window==='undefined'?globalThis:window);
