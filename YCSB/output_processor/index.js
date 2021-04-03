const Zip = require('adm-zip');
const path = require('path');
const fs = require('fs');
const csvWriter= require('csv-writer');

const readResultLine = (lines, lineHint) => {
  try {
    const runTimeLine = lines.find(line => line.includes(lineHint));
    if (runTimeLine) {
      const res = runTimeLine.split(',')[2].trim();
      if (res) {
        return res;
      }
    }
  } catch (e) {
    console.error("cant find line: ", lineHint);
  }
  return "";
}

const run = () => {
  const directoryPath = path.join(__dirname, '../outputs');
  const resultLines = [];
  fs.readdir(directoryPath, function (err, files) {
    files
      .filter(fileName => path.extname(fileName) === '.zip')
      .forEach(zipFileName => {
        //decode zipFile name
        const splitZipFileName = zipFileName.split('_');
        const testDate = splitZipFileName[6].split('.')[0]; //test date
        const zipFilePath = path.join(directoryPath, zipFileName)
        const zipFile = new Zip(zipFilePath);
        const workResults = zipFile.getEntries();
        workResults.forEach((workResultTxt) => {
          const workResultNameSplit = workResultTxt.name.split('-'); // ex: load-workload_80_20-3-10000-10000.txt run-workload_20_80-3-10000-10000.txt run-cluster-workload_20_80-3-10000-10000.txt
          let workType, workloadFile, serverCount, recordCount, opsCount;
          if (workResultNameSplit.length > 5) { //it means it's a cluster ex: run-cluster-workload_20_80-3-10000-10000.txt
            workType = `${workResultNameSplit[0]}-${workResultNameSplit[1]}`;
            workloadFile = workResultNameSplit[2];
            serverCount = workResultNameSplit[3];
            recordCount = workResultNameSplit[4];
            opsCount = workResultNameSplit[5].split('.')[0]; //remove .txt part
          } else {
            workType = workResultNameSplit[0]; //load or run
            workloadFile = workResultNameSplit[1];
            serverCount = workResultNameSplit[2];
            recordCount = workResultNameSplit[3];
            opsCount = workResultNameSplit[4].split('.')[0]; //remove .txt part
          }
          const workResultLines = workResultTxt.getData('utf8').toString().split('\n');
          const runtime = readResultLine(workResultLines, "[OVERALL], RunTime");
          const throughput = readResultLine(workResultLines, "[OVERALL], Throughput");
          resultLines.push([testDate, workType, workloadFile, serverCount, recordCount, opsCount, runtime, throughput]);
        });
      });
    const writer = csvWriter.createArrayCsvWriter({
      path: 'results.csv',
      header: ['Test Date', 'Work Type', 'Work Load File', 'Server Count', 'Record Count', 'Ops Count', 'Runtime (ms)', 'Throughput (ops/sec)']
    });
    writer.writeRecords(resultLines)
      .then(() => {
        console.log('Done.');
      });
  });
}

run();


