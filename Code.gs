function getByName(colName, row) {

  // source: https://stackoverflow.com/questions/36346918/get-column-values-by-column-name-not-column-index

  var sheet = SpreadsheetApp.getActiveSheet();
  var data = sheet.getDataRange().getValues();
  var col = data[0].indexOf(colName);
  if (col != -1) {
    return data[row-1][col];
  }
}

function doGet(e){
  
  var ss = SpreadsheetApp.getActive();
  var sheet = ss.getSheetByName(e.parameter["id"]);
  
  // Updating Google Sheet
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  var lastRow = sheet.getLastRow();
  var cell = sheet.getRange('a1');
  var col = 0;
  var d = new Date();

  for (i in headers){

    // loop through the headers and if a parameter name matches the header name insert the value

    if (headers[i] == "Timestamp")
    {
      val = d.toDateString() + ", " + d.toLocaleTimeString();
    }
    else
    {
      val = e.parameter[headers[i]]; 
    }

    // append data to the last row
    cell.offset(lastRow, col).setValue(val);
    col++;
  }

  // Sending e-mails
  var sh = SpreadsheetApp.getActiveSheet();
  var lastRow = sh.getLastRow();
  var temp = getByName("Temperature", lastRow)
  var pres = getByName("Pressure", lastRow)
  var threshold = e.parameter["thresh"]
  
  if(temp > threshold) 
  {
    var to = e.parameter["email"]
    var message = "Stats recorded: \n\n";
    message += "Temperature: " + temp + " °C \n"; 
    message += "Pressure: " + pres + " Pa \n"; 

    MailApp.sendEmail(to, " High temperature alert! ", message);
  }

  return ContentService.createTextOutput('success');
}

