#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Function GetDataByBarCodes(Barcodes) Export

	DataByBarCodes = New Map;

	Query = New Query(
	"SELECT
	|	Reg.Barcode AS Barcode,
	|	Reg.ProductsAndServices AS ProductsAndServices,
	|	Reg.Characteristic AS Characteristic,
	|	Reg.Batch AS Batch,
	|	Reg.MeasurementUnit AS MeasurementUnit
	|FROM
	|	InformationRegister.ProductsAndServicesBarcodes AS Reg
	|WHERE
	|	Reg.Barcode IN(&BarcodesArray)");

	BarcodesArray = New Array;

	For Each CurBarcode IN Barcodes Do
		BarcodesArray.Add(CurBarcode.Barcode);
		DataByBarCodes.Insert(CurBarcode.Barcode, New Structure);
	EndDo;

	Query.SetParameter("BarcodesArray", BarcodesArray);

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		CurData = DataByBarCodes[Selection.Barcode];
		CurData.Insert("ProductsAndServices", Selection.ProductsAndServices);
		CurData.Insert("Characteristic", Selection.Characteristic);
		CurData.Insert("Batch", Selection.Batch);
		CurData.Insert("MeasurementUnit", Selection.MeasurementUnit);
	EndDo;

	Return DataByBarCodes;

EndFunction

#EndRegion

#Region BarcodeGeneration

// Function calculates the control code character EAN
//
// Parameters:
//  Barcode     - barcode (without control digit)
//  Type        - barcode type: 13 - EAN13, 8 - EAN8
//
// Returns:
//  Control barcode character
//
Function CheckCharacterEAN(Barcode, Type) Export
	
	Parit   = 0;
	Odd = 0;
	
	IterationsQuantity = ?(Type = 13, 6, 4);
	
	For IndexOf = 1 To IterationsQuantity Do
		If (Type = 8) and (IndexOf = IterationsQuantity) Then
		Else
			Parit   = Parit   + Mid(Barcode, 2 * IndexOf, 1);
		EndIf;
		Odd = Odd + Mid(Barcode, 2 * IndexOf - 1, 1);
	EndDo;
	
	If Type = 13 Then
		Parit = Parit * 3;
	Else
		Odd = Odd * 3;
	EndIf;
	
	CheckDigit = 10 - (Parit + Odd) % 10;
	
	Return ?(CheckDigit = 10, "0", String(CheckDigit));
	
EndFunction // CheckCharacterEAN()

Function GetMaximumValueOfBarcodeCodeNumber(PrefixOfPieceProduct = "0", PrefixOfInnerBarcode = "00") Export
	
	Query = New Query(
		"SELECT
		|	MAX(SubString(ProductsAndServicesBarcodes.Barcode, 5, 8)) AS Code
		|FROM
		|	InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
		|WHERE
		|	ProductsAndServicesBarcodes.Barcode LIKE &BarcodeTemplate"
	);
	
	BarcodeTemplate = "2" + PrefixOfPieceProduct + PrefixOfInnerBarcode + "_________";
	Query.SetParameter("BarcodeTemplate", BarcodeTemplate);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	NumberTypeDescription = New TypeDescription("Number");
	ValueOfCodeNumber = NumberTypeDescription.AdjustValue(Selection.Code);
	
	Return ValueOfCodeNumber;
	
EndFunction // GetMaximumValueOfBarcodeCodeNumber()

Function GetBarcodeByCode(Code, PrefixOfPieceProduct = "0", PrefixOfInnerBarcode = "00") Export

	Barcode = "2" + PrefixOfPieceProduct + PrefixOfInnerBarcode + Format(Code, "ND=8; NLZ=; NG=");
	Barcode = Barcode + CheckCharacterEAN(Barcode, 13);
	
	Return Barcode;

EndFunction // GetBarcodeByCode()

// Function returns the weight product barcode generated from code
// with weight product prefix and control character
//
// Parameters:
//  Code                   - Code
//  WeightProductPrefix    - String
//
// Returns:
//  String
//
Function GetWeightProcuctBarcodeByCode(Code, WeightProductPrefix = "1") Export

	Barcode = "2" + WeightProductPrefix + Format(Code, "ND=5; NLZ=; NG=") + "00000";
	Barcode = Barcode + CheckCharacterEAN(Barcode, 13);

	Return Barcode;

EndFunction

// The function returns the goods sold by weight used to generate barcode.
// Used for loading to scales with printing labels
//
// Parameters:
//  PeripheralsRef - Ref
//
// Returns:
//  String
//
Function WeightProductPrefix(PeripheralsRef) Export
	
	Query = New Query(
	"SELECT
	|	ISNULL(Peripherals.ExchangeRule.WeightProductPrefix, 0) AS WeightProductPrefix
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Ref = &Ref");
	
	Query.SetParameter("Ref", PeripheralsRef);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		WeightProductPrefix = Selection.WeightProductPrefix;
		If ValueIsFilled(WeightProductPrefix) Then
			Return String(Selection.WeightProductPrefix);
		Else
			Return "1";
		EndIf;
	Else
		Return "1";
	EndIf;
	
EndFunction

// Function executes barcode formation EAN13
// for piece product
//
// Parameters:
//  PieceProductPrefix       - String 
//  InternalBarcodePrefix    - String
//  MaximumCode              - Number
//
// Returns:
//  String
//
Function GenerateBarcodeEAN13(PrefixOfPieceProduct = "0", PrefixOfInnerBarcode = "00", MaximumCode = 99999999) Export

	Code = min(GetMaximumValueOfBarcodeCodeNumber(PrefixOfPieceProduct, PrefixOfInnerBarcode) + 1, MaximumCode);

	Return GetBarcodeByCode(Code, PrefixOfPieceProduct, PrefixOfInnerBarcode);

EndFunction

// Function executes barcode formation EAN13
// for weight product
//
// Parameters:
//  WeightProductPrefix       - String       
//  MaximumCode               - Number
//
// Returns:
//  String
//
Function GenerateBarcodeVehicleWeightGoodsEAN13(WeightProductPrefix = "1", MaximumCode = 99999) Export

	Code = min(GetWeightBarcodeMaximumCodeValueAsNumber(WeightProductPrefix) + 1, MaximumCode);

	Return GetWeightProcuctBarcodeByCode(Code, WeightProductPrefix);

EndFunction

// Function returns the maximum barcode value as number
//
// Parameters:
//  WeightProductPrefix       - String
//
// Returns:
//  Number
//
Function GetWeightBarcodeMaximumCodeValueAsNumber(WeightProductPrefix = "1") Export

	Query = New Query("
	|SELECT
	|	MAX(SubString(ProductsAndServicesBarcodes.Barcode, 3, 5)) AS Code
	|FROM
	|	InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
	|WHERE
	|	ProductsAndServicesBarcodes.Barcode LIKE &BarcodeFormat
	|");

	Query.SetParameter("BarcodeFormat", InformationRegisters.ProductsAndServicesBarcodes.WeightBarcodeFormat(WeightProductPrefix));
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	NumberTypeDescription = New TypeDescription("Number");
	ValueOfCodeNumber = NumberTypeDescription.AdjustValue(Selection.Code);
	
	Return ValueOfCodeNumber;

EndFunction

// Function returns the weight barcode format for queries
//
// Parameters:
//  WeightBarcodePrefix - String
//
// Returns:
//  String
//
Function WeightBarcodeFormat(WeightOfBarcodePrefix) Export
	
	Return "2" + WeightOfBarcodePrefix + "_____00000_";
	
EndFunction

// Function returns weight barcode prefix array
Function GetPrefixesWeightBarcodes() Export
	
	SetPrivilegedMode(True);
	
	ReturnValue = New Array;
	
	Query = New Query(
	"SELECT DISTINCT
	|	ExchangeWithPeripheralsOfflineRules.WeightProductPrefix AS Prefix
	|FROM
	|	Catalog.ExchangeWithPeripheralsOfflineRules AS ExchangeWithPeripheralsOfflineRules");
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		ReturnValue.Add(String(Selection.Prefix));
	EndDo;
	
	Return ReturnValue;
	
EndFunction

// Procedure executes barcode conversion
// received from scales with label printing in barcode suitable for search in the database.
//
// Parameters:
//  CurBarcode               - String
//  WeightBarcodePrefixes - Array
//
Procedure ConvertWeightBarcode(CurBarcode) Export
	
	PrefixesWeightBarcodes = GetPrefixesWeightBarcodes();
	
	If StrLen(CurBarcode.Barcode) = 13 // EAN13
		AND Left(CurBarcode.Barcode, 1) = "2" // Internal barcode
		AND PrefixesWeightBarcodes.Find(Mid(CurBarcode.Barcode, 2, 1)) <> Undefined Then // Weight product prefix is found
		
		// Barcode is weigth, Performing conversion.
		// Format weight barcode: 2 + P + ChChChChCh + BBBBB + K
		// Where,
		//  P          - Product weight prefix 
		//  ChChChChCh - weight product code 
		//  BBBBB      - Weight 
		//  K          - Control number
		
		InternalBarcode12 = Left(CurBarcode.Barcode, 7) + "00000";
		InternalBarcode13 = InternalBarcode12 + InformationRegisters.ProductsAndServicesBarcodes.CheckCharacterEAN(InternalBarcode12, 13);
		Weight = Number(Mid(CurBarcode.Barcode, 8, 2)) + Number(Mid(CurBarcode.Barcode, 10, 3)) / 1000;
		
		CurBarcode.Barcode   = InternalBarcode13;
		CurBarcode.Quantity = CurBarcode.Quantity * Weight;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf