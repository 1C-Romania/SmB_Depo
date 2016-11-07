
#Region WorkMethodsWithBarcodeScanner

///////////////////////////////////////////////////
// THE METHODS OF WORK WITH THE BAOCRDE SCANNER

Function ConvertDataFromScannerIntoArray(Parameter) Export 

  Data = New Array;
	Data.Add(ConvertDataFromScannerIntoStructure(Parameter));
	
	Return Data;
	
EndFunction

Function ConvertDataFromScannerIntoStructure(Parameter) Export
	
	If Parameter[1] = Undefined Then
		Data = New Structure("Barcode, Quantity", Parameter[0], 1); 	 // Get a barcode from the basic data
	Else
		Data = New Structure("Barcode, Quantity", Parameter[1][1], 1); // Get a barcode from the additional data
	EndIf;
	
	Return Data;
	
EndFunction

#EndRegion
