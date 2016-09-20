
#Region ProgramInterface

// Function connects a device.
//
// Parameters:
//  DriverObject   - <*>
//           - DriverObject of a trading equipment driver.
//
// Returns:
//  <Boolean> - Result of the function work.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Result      		= True;
	Output_Parameters 	= New Array();
	DriverObject 		= Undefined;

	ProductsBase  = Undefined;
	ReportFile    = Undefined;
	ExportFlag  = Undefined;

	Parameters.Property("ProductsBase",  ProductsBase);
	Parameters.Property("ReportFile",   ReportFile);
	Parameters.Property("ExportFlag", ExportFlag);

	If ProductsBase  = Undefined
	 Or ReportFile   = Undefined
	 Or ExportFlag = Undefined  Then
	 	Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.';ru='Не настроены параметры устройства.
		|Для корректной работы устройства необходимо задать параметры его работы.'"));
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
//         - DriverObject of a trading equipment driver.
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

	// Export products to Cash Register Offline.
	If Command = "ExportProducts" Then
		Products 				= InputParameters[0];
		PartialExport 	= InputParameters[1];
		Result = ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters);

	// Export sales data (report) from Cash register Offline.
	ElsIf Command = "ImportReport" Then

		Result = ImportReport(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
											  
	// Determines a report import result.
	ElsIf Command = "ReportImported" Then
		
		Result = ReportImported(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
											  
	// Clear CR base Offline
	ElsIf Command = "ClearBase" Then

		Result = ClearProductsOnCR(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Test device
	ElsIf Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// This command is not supported by the current driver.
	Else
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.';ru='Команда ""%Команда%"" не поддерживается данным драйвером.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);

		Result = False;
	EndIf;

	Return Result;

EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// The function imports a product table to the Cash register Offline.
//
// Parameters:
//  DriverObject                 - <*>
//                               - Driver object of the trading equipment.
//
//  Products                     - <ValueTable>
//                               - Table of products to be imported to Cash register.
//                                 The table has the following columns:
//                                     Code                       - <Number>
//                                                                - Product identifier in the cash receipt.
//                                     Barcode                    - <Number>, <String>
//                                                                - Code of a product sold
//                                                                  by weight or a barcode (for products sold by items).
//                                     Description               - <String>
//                                                               - Short product name (to print in the receipt).
//                                     DescriptionFull           - <String>
//                                                               - Full product name (to show
//                                                                 on the screen).
//                                     MeasurementUnit           - <CatalogRef.UOM>
//                                                               - Measurement unit of products and services.
//                                     Price                     - <Number>
//                                                               - Products and services price.
//                                     Balance                   - <Number>
//                                                               - Remaining products in the petty cash warehouse.
//                                     WeightProduct             - <Boolean>
//                                                               - Product is sold by weight.
//
//  PartialExport                - <Boolean>
//                                  - Shows that products are partially exported.
//
Function ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters)
	
	// Cannot process a new partial export unless the previous one is imported.
	If PartialExport AND
		Not ProductsExportingAllowed(Parameters) Then
		Output_Parameters.Add(999);
		ErrorDescription = NStr("en='Cannot export. Products of the previous export have not been received by CR-offline yet';ru='Нельзя сделать выгрузку. Товары предыдущей выгрузки еще не были получены ККМ-offline'");
		Output_Parameters.Add(ErrorDescription);
		Return False;
	EndIf;
	
	mDelimiter = GetDelimiter();
	Result = True;

	File = New TextDocument();

	File.AddLine("##@@&&");
	File.AddLine("#");

	If PartialExport = False Then
		File.AddLine("$$$DELETEALLWARES");
		File.AddLine("$$$DELETEALLBACODES");
		File.AddLine("$$$DELETEALLASPECTREMAINS");
	Else
		File.AddLine("$$$REPLACEQUANTITY");
	EndIf;

	For Each Product IN Products Do
		If TypeOf(Product.Barcode) <> Type("Array") Then

			String =   Format(Number(Product.Code), "ND=20; NFD=0; NZ=0; NG=0")       + mDelimiter // Code (1)
			         + Format(String(Product.Barcode), "ND=20; NFD=0; NZ=0; NG=0")  + mDelimiter // Barcode (2)
			         + PrepareString(Product.DescriptionFull)                 + mDelimiter // Name (3)
			         + PrepareString(Product.Description)      		           + mDelimiter // Receipt text (4)
			         + Format(Product.Price, "ND=15; NFD=2; NZ=0; NG=0")       + mDelimiter // Price (5)
			         + Format(Product.Balance, "ND=17; NFD=3; NZ=0; NG=0")    + mDelimiter // Balance
			         // (6) Scheme of internal automatic discount (7).
			         + "0"                                                  + mDelimiter
			         + ?(Product.WeightProduct, 1, 0)                                      // Comma-separated check boxes: (8)
			                                                                               // • fractional quantity (weight)
			                                                                               // • sales 
			                                                                               // • return
			                                                                               // • negative balance 
			                                                                               // • without entering quantity
			                                                                               // • write off
			                                                                               // • edit price
                                                                                    // • enter quantity manually
			         + ",1,1,0,0,0," + ?(Product.Price = 0, "1", "0") + ",1"   + mDelimiter
			         + ""                                                   + mDelimiter // Minimum price (9)
			         + ""                                                   + mDelimiter // Expiration date (10)
			         + ""                                                   + mDelimiter // Code of section
			         // scheme (11) Section use option (12).
			         + ""                                                   + mDelimiter
			         // Code of external automatic discount scheme (13).
			         + ""                                                   + mDelimiter
			         + Format(?(TypeOf(Product.MeasurementUnit) = Type("String"), "", Product.MeasurementUnit.Factor),
			                  "ND=7; NFD=3; NZ=0; NG=0")                    + mDelimiter // Ratio (14)
			         + ""                                                   + mDelimiter // Basic product code (15)
			         + ""                                                   + mDelimiter // Parent group code (16).
			         // Product or group: for product "1" Product or group: for group "0" (17).
			         + "1"                                                  + mDelimiter
			         // Number of hierarchical list level (18).
			         + "0"                                                  + mDelimiter
			         // Code of the first section value of a scheme with code "1" (19).
			         + ""                                                   + mDelimiter
			         + ""							                        + mDelimiter // Products and services series (20)
			         + ""                                                   + mDelimiter // Certificate (21)
			         + ""                                                   + mDelimiter // CR code (22)
			         + ""                                                   + mDelimiter // Tax group code (23)
			         + ""                                                   + mDelimiter // Code of scales with labels print (24)
			         + ?(Product.WeightProduct, Format(Number(Product.Code),"NZ=0; NG=0"), "") + mDelimiter // Product code in scales with labels print (25)
			         + ?(Product.Property("SKU"), PrepareString(Product.SKU), "") + mDelimiter // SKU (26)
			         + ""                                                   + mDelimiter   // Discount/markup type: (27)
			                                                                               //  0 - percentage discount 
			                                                                               //  1 - discount in sum
			                                                                               //  2 - percentage markup 
			                                                                               //  3 - allowance in sum
			         // Discount/markup value (28)
			         + ""                                                   + mDelimiter
			         + ""                                                   + mDelimiter // Maximum discount, % (29)
			         + ""                                                   + mDelimiter // Receipt printer code (30)
			         + ""                                                   + mDelimiter // *.bmp file with an image (31)
			         + ""                                                   + mDelimiter // Description (32)
			         + "";                                                               // Quantity multiplicity (33)

			File.AddLine(String);
		Else

			Barcode = ""; Comma = "";
			For Each ArrayRow IN Product.Barcode Do
				Barcode = Barcode + Comma + ArrayRow;
				Comma = ",";
			EndDo;

			ProductDescription = Product.Description;

			String =   Format(Number(Product.Code), "ND=20; NFD=0; NZ=0; NG=0") + mDelimiter // Code
			         + Barcode                                                  + mDelimiter // Barcode
			         + PrepareString(Product.DescriptionFull)                   + mDelimiter // Description
			         + PrepareString(Product.Description)                       + mDelimiter // Receipt text
			         + Format(Product.Price, "ND=15; NFD=2; NZ=0; NG=0")        + mDelimiter // Price
			         + Format(Product.Balance, "ND=17; NFD=3; NZ=0; NG=0")      + mDelimiter // Balance
			         // Scheme of internal automatic discount.
			         + "0"                                                      + mDelimiter
			         + ?(Product.WeightProduct, 1, 0)                                         // Comma-separated flags:
			                                                                                  // • fractional quantity (weight)
			                                                                                  // • sales
			                                                                                  // • return 
			                                                                                  // • negative balance 
			                                                                                  // • without entering quantity 
			                                                                                  // • write off remaining products
			                                                                                  // • edit price 
			                                                                                  // • enter quantity manually
			         + ",1,1,0,0,0," + ?(Product.Price = 0, "1", "0") + ",1"   + mDelimiter
			         + ""                                                   + mDelimiter // Minimum price
			         + ""                                                   + mDelimiter // Expiration date
			         + ""                                                   + mDelimiter // Section scheme code
			         + ""                                                   + mDelimiter // Sections use option:
			                                                                               //  0 - full list 
			                                                                               //  1 - set list 
			                                                                               //  2 - set list with balance
			         // Code of external automatic discount scheme
			         + ""                                                   + mDelimiter
			         + Format(?(TypeOf(Product.MeasurementUnit) = Type("String"), "", Product.MeasurementUnit.Factor),
			                  "ND=7; NFD=3; NZ=0; NG=0")                    + mDelimiter // Ratio (14)
			         + ""                                                   + mDelimiter // Basic product code
			         + ""                                                   + mDelimiter // Parent group
			         // code Product or group: for product "1" Product or group: for group "0".
			         + "1"                                                  + mDelimiter
			         + "0"                                                  + mDelimiter // Hierarchical list level number.
			         // Code of the first section value of a scheme with code "1".
			         + ""                                                   + mDelimiter
			         + ""							                        + mDelimiter // Products and services series
			         + ""                                                   + mDelimiter // Certificate
			         + ""                                                   + mDelimiter // CR code
			         + ""                                                   + mDelimiter // Tax group code
			         + ""                                                   + mDelimiter // Scales code with labels print
			         + ?(Product.WeightProduct, Format(Number(Product.Code), "NZ=0; NG=0"), "") + mDelimiter // Product code in scales with labels print
			
			         + ?(Product.Property("SKU"), PrepareString(Product.SKU), "") + mDelimiter // SKU (26)
			         + ""                                                   + mDelimiter // Discount/markup type:
			                                                                               //  0 - percentage discount 
			                                                                               //  1 - discount  in sum
			                                                                               //  2 - percentage markup 
			                                                                               //  3 - allowance in sum
			         + ""                                                   + mDelimiter // Discount/markup value
			         + ""                                                   + mDelimiter // Maximum discount, %
			         + ""                                                   + mDelimiter // Receipt printer code
			         + ""                                                   + mDelimiter // *.bmp file with an image
			         + ""                                                   + mDelimiter // Definition
			         + "";                                                               // Quantity multiplicity

			File.AddLine(String);
		EndIf;
		
	EndDo;

	Try
		File.Write(Parameters.ProductsBase, TextEncoding.ANSI);
		If Not IsBlankString(Parameters.ExportFlag) Then
			File.Clear();
			File.Write(Parameters.ExportFlag, TextEncoding.ANSI);
		EndIf;
	Except
		Output_Parameters.Add(999);
		ErrorDescription = NStr("en='Failed to record products file at address: %Address%';ru='Не удалось записать файл товаров по адресу: %Адрес%'");
		Output_Parameters.Add(StrReplace(ErrorDescription, "%Address%", Parameters.ProductsBase));
		Result = False;
	EndTry;

	Return Result;

EndFunction // ExportProducts()

// The function exports a sales report from the Cash register Offline.
//
// Parameters:
//  Object                         - <*>
//                                 - Driver object of the trading equipment.
//
//  Report                          - <ValueTable>
//                                 - Output parameter; table that
//                                   contains sales data for a shift. The
//                                   table has the following columns:
//                                     Code        - <Number>
//                                                 - ID of
//                                                   sold (returned) product.
//                                     Price       - <Number>
//                                                 - Price per product item.
//                                     Quantity    - <Number>
//                                                 - Quantity of sold
//                                                  (>0) or returned (<0) products.
//                                     Discount    - <Number>
//                                                 - Percent of the provided discount.
//                                     Amount      - <Number>
//                                                 - Item amount: >0 - sale, <0 - return.
//
// Returns:
//  <EnumRef.ErrorDetails*> - Result of the function work.
//
Function ImportReport(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 
    mDelimiter			= GetDelimiter();
	Result           	= True;
	UnknownTransaction 	= False;
	LastShiftNumber 	= 0;

	Report 	= New Array;
	Receipts 	= New Array;
	Positions = New Array;
	
	File = New TextDocument();
	Try
		File.Read(Parameters.ReportFile);
	Except
		Output_Parameters.Add(999);
		ErrorDescription = NStr("en='Cannot receive a report file by address: %Address%';ru='Не удалось прочитать файл отчета по адресу: %Адрес%'");
		Output_Parameters.Add(StrReplace(ErrorDescription, "%Address%", Parameters.ReportFile));
		Result = False;
	EndTry;
	If Result Then
		CurrentRow = File.GetLine(1);
		If CurrentRow = "#" Then
			RowIndex  = 4;
			CurrentRow = File.GetLine(RowIndex);
			While Not IsBlankString(CurrentRow) Do
				CurrentRow = StrReplace(CurrentRow, mDelimiter, Chars.LF);

				TransactionNoStr   = StrGetLine(CurrentRow,  1);
				OperationKindStr   = StrGetLine(CurrentRow,  4);
				DocumentNumberStr  = StrGetLine(CurrentRow,  6);
				ReasonCodeStr      = StrGetLine(CurrentRow,  9);
				ShiftNumberStr     = StrGetLine(CurrentRow, 14);

				Try
					ErrorField = NStr("en='Transaction number (1)';ru='Номер транзакции (1)'");
					TransactionNo    = Number(TransactionNoStr);
					ErrorField = NStr("en='Transaction type (4)';ru='Тип транзакции (4)'");
					OperationKind      = Number(OperationKindStr);
					ErrorField = NStr("en='Document number (6)';ru='Номер документа (6)'");
					DocumentNumber     = Number(DocumentNumberStr);
					ErrorField = NStr("en='Number of session (14)';ru='Номер смены (14)'");
					NumberOfSession         = Number(ShiftNumberStr);
				Except
					Output_Parameters.Add(999);
					Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
					Result = False;
					Break;
				EndTry;

				If LastShiftNumber < NumberOfSession Then
					LastShiftNumber = NumberOfSession;
				EndIf;

				If OperationKind =  1 Then
					// Registration without a product code.
					Output_Parameters.Add(999);
					Output_Parameters.Add(NStr("en='Sales registration ignoring the item codes is not available';ru='Регистрация продаж без учета кода товара не допускается'"));
					Result = False;
					Break;
				ElsIf OperationKind = 11 Then
					// Registration with a product code.
					StrCode        = StrGetLine(CurrentRow,  8);
					PriceStr       = StrGetLine(CurrentRow, 10);
					QuantityStr    = StrGetLine(CurrentRow, 11);
					AmountStr      = StrGetLine(CurrentRow, 16);
					SKU            = StrGetLine(CurrentRow, 18);
					Try
						ErrorField  = NStr("en='Product code (8)';ru='Код товара (8)'");
						Code        = Number(StrCode);
						ErrorField  = NStr("en='Product price (10)';ru='Цена товара (10)'");
						Price       = Number(PriceStr);
						ErrorField  = NStr("en='Products quantity (11)';ru='Количество товара (11)'");
						Quantity    = Number(QuantityStr);
						ErrorField  = NStr("en='Sales amount (16)';ru='Сумма продажи (16)'");
						Amount      = Number(AmountStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					Temp                = New Structure("Code, Price, Quantity, Sum, SKU, DocumentNumber, ShiftNumber");
					Temp.Code            = Code;
					Temp.Price           = Price;
					Temp.Quantity     = Quantity;
					Temp.Amount          = Amount;
					Temp.SKU        = SKU;
					Temp.DocumentNumber = DocumentNumber;
					Temp.NumberOfSession     = NumberOfSession;
					Positions.Add(Temp);
				ElsIf OperationKind =  2 Or OperationKind = 12 Then
					// Cancelling
					SearchStructure                = New Structure("DocumentNumber, ShiftNumber");
					SearchStructure.DocumentNumber = DocumentNumber;
					SearchStructure.NumberOfSession     = NumberOfSession;
					Temp                           = FindRows(Positions, SearchStructure);
					Temp                           = Temp[Temp.Count() - 1];
					Positions.Delete(Temp.IndexInArray);
				ElsIf OperationKind =  4 Or OperationKind = 14 Then
					// Tax
				ElsIf OperationKind =  5 Or OperationKind = 15 Or OperationKind =  7 Or OperationKind = 17 Then
					// Item discount
				ElsIf OperationKind =  6 Or OperationKind = 16 Or OperationKind =  8 Or OperationKind = 18 Then
					// Item markup
				ElsIf OperationKind = 85 Or OperationKind = 75
						  Or OperationKind = 87 Or OperationKind = 77 Then
					// Allocated discount
				ElsIf OperationKind = 86 Or OperationKind = 76
						  Or OperationKind = 88 Or OperationKind = 78 Then
					// Allocated markup
				ElsIf OperationKind = 60 Then
					// X-report
				ElsIf OperationKind = 63 Then
					// Z-report
				ElsIf OperationKind = 64 Then
					// Opening shift document
				ElsIf OperationKind = 61 Then
					// Close shift
				ElsIf OperationKind = 62 Then
					// Open shift
				ElsIf OperationKind = 40 Then
					// Payment with displaying the client amount.
				ElsIf OperationKind = 41 Then
					// Payment without displaying the client amount.
				ElsIf OperationKind = 42 Then
					// Open receipt
					Temp = New Structure("DocumentNumber, ShiftNumber, ReceiptClosed, Discount");
					Temp.DocumentNumber = DocumentNumber;
					Temp.NumberOfSession     = NumberOfSession;
					Temp.ReceiptClosed      = False;
					Temp.Discount         = 0;
					Receipts.Add(Temp);
				ElsIf OperationKind = 43 Then
					// Payment allocation
				ElsIf OperationKind = 45 Then
					// Closing document in CR
				ElsIf OperationKind = 49 Then
					// Closing document on GP
				ElsIf OperationKind = 50 Then
					// Deposit
				ElsIf OperationKind = 51 Then
					// Payment
				ElsIf OperationKind = 55 Then
					// Closing receipt
					SearchStructure                = New Structure("DocumentNumber, ShiftNumber");
					SearchStructure.DocumentNumber = DocumentNumber;
					SearchStructure.NumberOfSession     = NumberOfSession;
					TimPosition                    = FindRows(Positions, SearchStructure);

					PositionsAmount                   = 0;
					For Each Position IN TimPosition Do
						PositionsAmount = PositionsAmount + Position.Amount;
					EndDo;

					TempReceipts = FindRows(Receipts, SearchStructure)[0];
					TempReceipts.ReceiptClosed = True;
				ElsIf OperationKind = 56 Then
					// The receipt is not closed in CR
					SearchStructure                = New Structure("DocumentNumber, ShiftNumber");
					SearchStructure.DocumentNumber = DocumentNumber;
					SearchStructure.NumberOfSession     = NumberOfSession;
					Temp                           = FindRows(Positions, SearchStructure);
					For IndexOf = 1 To Temp.Count() Do
						TempRow                 = Temp[Temp.Count() - IndexOf];
						Positions.Delete(TempRow.IndexInArray);
					EndDo;
				ElsIf OperationKind = 57 Then
					// Restoring a deferred receipt.
				ElsIf OperationKind = 35 Or OperationKind = 37 Then
					// Receipt discount
				ElsIf OperationKind = 36 Or OperationKind = 38 Then
					// Receipt markup
				ElsIf OperationKind = 21 Or OperationKind = 23 Then
					// Registering banknotes by a free price.
				ElsIf OperationKind = 22 Or OperationKind = 24 Then
					// Reversing entry of the banknotes by a free price / from catalog.
				Else
					ErrorDescription = NStr("en='Unknown transaction has been detected: %OperationKind%. Data by transaction has not been imported!';ru='Обнаружена неизвестная транзакция: %ТипТранзакции%. Данные по транзакции не были загружены!'");
					CommonUseClientServer.MessageToUser(StrReplace(ErrorDescription, "%OperationKind%", String(OperationKind)));
					UnknownTransaction = True;
				EndIf;

				RowIndex  = RowIndex + 1;
				CurrentRow = File.GetLine(RowIndex);
			EndDo;

			If UnknownTransaction Then
				CommonUseClientServer.MessageToUser(NStr("en='Not all data has been exported from the report. Contact the system administrator!';ru='Не все данные были загружены из отчета. Обратитесь к администратору системы!'"));
			EndIf;
		ElsIf CurrentRow = "@" Then
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Operation is aborted. The report was already loaded!';ru='Операция прервана. Отчет уже был загружен!'"));
			Result = False;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Incorrect data format or data is absent.';ru='Неверный формат данных или данные отсутствуют.'"));
			Result = False;
		EndIf;
	EndIf;

	If Result Then
		SearchStructure            = New Structure("ReceiptClosed");	
		SearchStructure.ReceiptClosed  = True;
		Temp                       = FindRows(Receipts, SearchStructure);
		For Each Receipt IN Temp Do
			SearchStructure                = New Structure("DocumentNumber");
			SearchStructure.DocumentNumber = Receipt.DocumentNumber;
			ReceiptPosition = FindRows(Positions, SearchStructure);
			For Each Position IN ReceiptPosition Do
				
				DiscountTemp = (Position.Price * Position.Quantity) - Position.Amount;
				If Position.Amount = 0  AND  Position.Price * Position.Quantity > 0 Then
					DiscountTemp = 100;
				ElsIf Position.Price * Position.Quantity = 0 Then
					DiscountTemp = 0;
				Else
					DiscountTemp = Round(DiscountTemp / (Position.Price * Position.Quantity) * 100, 2);
				EndIf;
				
				ResPosition = New Structure("Code, Quantity, Price, Amount, Discount"
				, Position.Code
				, Position.Quantity
				, Position.Price
				, Position.Amount
				, DiscountTemp);
				Report.Add(ResPosition);
			EndDo;
		EndDo;
		Output_Parameters.Add(Report);
	EndIf;

	Return Result;

EndFunction // ImportReport()

// The function is called once the sales report is imported or processed.
//
// Parameters:
//  Object                         - <*>
//                                 - Driver object of the trading equipment.
//
// Returns:
//  <EnumRef.ErrorDetails*> - Result of the function work.
//
Function ReportImported(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 

	Result = True;
	
	Try
		Document = New TextDocument();
		Document.Read(Parameters.ReportFile, TextEncoding.ANSI);
		Document.ReplaceLine(1, "@");
		Document.Write(Parameters.ReportFile, TextEncoding.ANSI);
	Except
	EndTry;
	
	Return Result;
	
EndFunction // ReportImported()

// The function clears products in the cash register Offline.
// 
Function ClearProductsOnCR(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 

	Result = True;

	File = New TextDocument();

	File.AddLine("##@@&&");
	File.AddLine("#");

	File.AddLine("$$$DELETEALLWARES");
	File.AddLine("$$$DELETEALLBACODES");
	File.AddLine("$$$DELETEALLASPECTREMAINS");

	Try
		File.Write(Parameters.ProductsBase, TextEncoding.ANSI);
		If Not IsBlankString(Parameters.ExportFlag) Then
			File.Clear();
			File.Write(Parameters.ExportFlag, TextEncoding.ANSI);
		EndIf;
	Except
		Result = False;
	EndTry;

	Return Result;

EndFunction // ImportReport()

// The function returns a flag showing that the previous version is imported.
// If the result is True - then a product can be exported overwriting the existing file.
//
Function ProductsExportingAllowed(Parameters) 
	
	Result = False;
	
	Try
		File = New TextDocument();
		File.Read(Parameters.ProductsBase, TextEncoding.ANSI);
		String = File.GetLine(2);
		If StrLen(String) = 1
			AND Find(String,"#") > 0 Then
			Result = False; // Cannot if a character in the second row is "#".
		Else
			Result = True; // Possible if a character in the second row is not "#" (as a rule if the export is complete, the character is "@").
		EndIf;
	Except
		Result = True; // Possible if a product file does not exist.
	EndTry;

	Return Result;
	
EndFunction

// Function checks the paths where exchange files are stored.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 
	
	Result = True;
	ErrorText = "";
	CommonErrorText = "";
	TempParameter = "";
	
	Parameters.Property("ProductsBase", TempParameter);
	
	If IsBlankString(TempParameter) Then
		Result = False;
		CommonErrorText = NStr("en='Products base file is not specified.';ru='Файл базы товаров не указан.'");
	EndIf;
	
	Parameters.Property("ReportFile", TempParameter);
	If IsBlankString(TempParameter) Then
		Result = False;
		CommonErrorText = CommonErrorText + ?(IsBlankString(CommonErrorText), "", Chars.LF); 
		CommonErrorText = CommonErrorText + NStr("en='Report file is not specified.';ru='Файл отчета не указан.'") 
	EndIf;
	
	Output_Parameters.Add(?(Result, 0, 999));
	If Not IsBlankString(CommonErrorText) Then
		Output_Parameters.Add(CommonErrorText);
	EndIf;
	
	Return Result;
	
EndFunction

// The function returns fields delimiter of a table contained in the file.
//
Function GetDelimiter();
	
	Return ";";
	
EndFunction

// Prepares a row for export.
Function PrepareString(Val SourceLine);
	
	SourceLine = StrReplace(TrimAll(SourceLine), GetDelimiter(), " "); 
	SourceLine = StrReplace(SourceLine, "#", " "); 
	SourceLine = Left(SourceLine, 100);
		 
	Return SourceLine;
	
EndFunction

// Returns an item array found in the structure array by filter parameters. Filter parameters
// make a structure.
// Operates the same as the FindStrings method of the values table.
Function FindRows(SearchingArray, FilterParameters)
	Result = New Array;
	For y = 0 To SearchingArray.Count()-1 Do
		
		ArrayElement = SearchingArray[y];
		FullMatch = True;
		
		For Each FilterItem IN FilterParameters Do
			
			If ArrayElement.Property(FilterItem.Key) 
				AND Not FilterItem.Value = ArrayElement[FilterItem.Key] Then
				FullMatch = False;
			EndIf;
			
		EndDo;
		
		If FullMatch Then
			ArrayElement.Insert("IndexInArray", y);
			Result.Add(ArrayElement);
		EndIf;
		
	EndDo;
	Return Result;
EndFunction

#EndRegion
