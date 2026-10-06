(function(root){
function prepareEntries(students,values,kind,commonNote='',getBalance=()=>0){
 if(!['deposit','withdrawal'].includes(kind))throw Error('Jenis transaksi tidak valid.');
 const entries=[];
 for(const s of students){
  if(!s.active)continue;
  const raw=String(values['amount_'+s.id]??'').trim();if(!raw)continue;
  const amount=Number(raw);
  if(!/^\d+$/.test(raw)||!Number.isSafeInteger(amount)||amount<1||amount>1000000000)throw Error('Nominal '+s.name+' harus bilangan bulat Rp 1–1.000.000.000.');
  const note=String(values['note_'+s.id]??'').trim()||commonNote.trim()||(kind==='deposit'?'Setoran tabungan':'');
  if(kind==='withdrawal'&&!note)throw Error('Isi keterangan pengeluaran untuk '+s.name+'.');
  if(kind==='withdrawal'&&amount>getBalance(s.id))throw Error('Saldo '+s.name+' tidak mencukupi.');
  entries.push({student_id:s.id,amount,note});
 }
 if(!entries.length)throw Error('Isi nominal minimal satu siswa. Baris kosong dilewati.');
 if(entries.length>500)throw Error('Maksimal 500 siswa per penyimpanan.');
 return entries.sort((a,b)=>a.student_id.localeCompare(b.student_id));
}
root.SakuBulk={prepareEntries};
})(typeof window==='undefined'?globalThis:window);
