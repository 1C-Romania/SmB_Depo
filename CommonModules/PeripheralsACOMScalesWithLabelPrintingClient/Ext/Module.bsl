
#Region ProgramInterface

// Function connects a device.
//
// Parameters:
//  DriverObject   - <*>
//            - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Result      		= True;
	Output_Parameters 	= New Array();
	DriverObject 		= Undefined;

	ProductsBase  = Undefined;

	Parameters.Property("ProductsBase",  ProductsBase);

	If ProductsBase  = Undefined Then
	 	Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.'"));
		Result = False;
	Else
		DriverObject = New Structure("Parameters", Parameters);
	EndIf;

	Return Result;
	
EndFunction

// Function disconnects a device.
//
// Parameters:
//  DriverObject - <*>
//            - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	Result = True;
	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export
	 
	Result = True;
	Output_Parameters = New Array();
	
	// Export products to the scales with labels print.
	If Command = "ExportProducts" Then
		Products            = InputParameters[0];
		PartialExport = InputParameters[1];
		Result = ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters);
	  
	// Clear the base of scales with printing labels.
	ElsIf Command = "ClearBase" Then
		Result = ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// Test device
	ElsIf Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);

		Result = False;
	EndIf;

	Return Result;

EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Function exports the products table to the scales with labels printing.
//
// Parameters:
//  DriverObject                 - <*>
//                               - Driver object of the trading equipment.
//
//  Products                     - <ValueTable>
//                               - Table of products for exporting in the scales.
//                                 The table has the following columns:
//                                     PLU                        - <Number>
//                                                                - Product identifier in the scales.
// 								   Barcode 				  - <String>
//                                                                - Barcode of a product at the cash.
//                                     Description                - <String>
// 															  - Product short name (for printing on the label).
//                                     DescriptionFull            - <String>
// 															  - Product full name (for displaying on the screen).
//                                     Price                      - <Number>
//                                                                - Products and services price.
//
//  PartialExport               - <Boolean>
//                                 - Shows that products are partially exported.
//
Function ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters) 
	
	Result = True;
	Prefix = "2" + EquipmentManagerServerCallOverridable.GetWeightProductPrefix(Parameters.ID);
	If StrLen(Prefix) = 1 Then
		Prefix = Prefix + "0";
	EndIf;
	
	Status(NStr("en = 'Products are being exported to the scales with labels printing...'")); 
	
	File = New TextDocument();
	
	For Each CurItem IN Products Do
		
		If IsBlankString(CurItem.Code) Or (CurItem.Code = 0) Then
			ProductCodeTemp =  EquipmentManagerClient.ConstructField(Format(CurItem.Barcode, "NG=0"), 8)
		Else
            ProductCodeTemp =  EquipmentManagerClient.ConstructField(String(CurItem.Code), 8)
		EndIf;
		
		TempName = CurItem.Description; 
		
		If CurItem.Property("DescriptionFull") AND 
		  Not IsBlankString(CurItem.DescriptionFull) Then
			TempName = CurItem.DescriptionFull;
		EndIf;
		
		If CurItem.Property("StoragePeriod") Then	
			StoragePeriodTemp = CurItem.StoragePeriod;
		Else
			StoragePeriodTemp = 0;
		EndIf;
		
		If CurItem.Property("ProductDescription") Then	
			ProductDescriptionTemp = CurItem.ProductDescription;
		Else
			ProductDescriptionTemp = "";
		EndIf;
			
		String =  EquipmentManagerClient.ConstructField(Format(CurItem.PLU, "NG=0"), 8) + "|" 					// PLU (8)
		+  EquipmentManagerClient.ConstructField(TempName, 30) + "|" 										// Description1 (30)
		+  EquipmentManagerClient.ConstructField(Mid(TempName, 31, 30), 30) + "|"							// Description2
		// (30) Price (10)
		+  EquipmentManagerClient.ConstructField(Format(CurItem.Price * 100, "ND=8; NFD=0; NZ=0; NG=0"), 15) + "|"
		// Storage period (5)
		+ ?(StoragePeriodTemp = 0, "   ",  EquipmentManagerClient.ConstructField(Format(StoragePeriodTemp, "NZ=0; NG=0"), 3)) + "|"
		+ "       |"																				// Tare weight (7)
		+ "     |"																					// Use to (5)
		+ ProductCodeTemp + "|"																		// Product code (8)
		+  EquipmentManagerClient.ConstructField(Format(Prefix, "NZ=0; NG=0"), 4) + "|"								// Group code (4)
		+ "     |"																					// Producer code  (5)
		+ "   |"																					// PLD Type (3)
		+ "   |"																		// HeaderCode (3)
		+  EquipmentManagerClient.ConstructField(Mid(ProductDescriptionTemp, 1,   56), 56) + "|"				// Content1 58
		+  EquipmentManagerClient.ConstructField(Mid(ProductDescriptionTemp, 57,  56), 56) + "|"				// Content2 58
		+  EquipmentManagerClient.ConstructField(Mid(ProductDescriptionTemp, 113, 56), 56) + "|"				// Content3 58
		+ "                                                        |"					// Content4 58
		+ "                                                        |"					// Content5 58
		+ "                                                        |"					// Content6 58
		+ "                                                        |"					// Content7 58
		+ "                                                        |"					// Content8 58
		+ "                                                        |"					// Content9 58
		+ "                                                        ";					// Content10 58
		File.AddLine(String);
	EndDo;
	
	Try
		File.Write(Parameters.ProductsBase, TextEncoding.ANSI);
	Except
		Output_Parameters.Add(999);
		ErrorDescription = NStr("en='Failed to record products file at address: %Address%'");
		Output_Parameters.Add(StrReplace(ErrorDescription, "%Address%", Parameters.ProductsBase));
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// The function clears the products table to the scales with labels printing.
//
Function ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 

	Output_Parameters.Add(999);
	Output_Parameters.Add(NStr("en='These scales do not support the automatic items clearing.
	| Run the app of importing data to the scales for clearing products in the scales and click ""Clear PLU in scales"" button.'"));
	Result = False;

	Return Result;

EndFunction

// Function checks the paths where exchange files are stored.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 
	
	Result = True;
	Directory = Undefined;
	ErrorText = "";
	
	TempProductsBase = "";
	Parameters.Property("ProductsBase", TempProductsBase);
	
	If IsBlankString(TempProductsBase) Then
		Result = False;
		ErrorText = NStr("en='Products base file is not specified.'");
	EndIf;
		
	Output_Parameters.Add(?(Result, 0, 999));
	If Not IsBlankString(ErrorText) Then
		Output_Parameters.Add(ErrorText);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion