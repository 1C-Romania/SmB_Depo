
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
		Output_Parameters.Add(NStr("en='Device parameters are not set."
"For the correct work of the device it is necessary to specify the parameters of its work.';ru='Не настроены параметры устройства."
"Для корректной работы устройства необходимо задать параметры его работы.'"));
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
		Products            = InputParameters[0];
		PartialExport = InputParameters[1];
		Result = ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters);

	// Export sales data (report) from Cash register Offline.
	ElsIf Command = "ImportReport" OR Command = "ImportReport" Then
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
//                                     Code                - <Number>
//                                                         - Product identifier in the cash receipt.
//                                     Barcode             - <Number>, <String>
//                                                         - Code of a product sold
//                                                           by weight or a barcode (for products sold by items).
//                                     Description         - <String>
//                                                         - Short product name (to print in the receipt).
//                                     DescriptionFull     - <String>
//                                                         - Full product name (to show on the screen).
//                                     MeasurementUnit     - <CatalogRef.UOM>
//                                                         - Measurement unit of products and services.
//                                     Price               - <Number>
//                                                         - Products and services price.
//                                     Balance             - <Number>
//                                                         - Remaining products in the petty cash warehouse.
//                                     WeightProduct       - <Boolean>
//                                                         - Product is sold by weight.
//
//  PartialExport               - <Boolean>
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
	
	Delimiter = GetDelimiter();
	Result = True;

	File = New TextDocument();

	File.AddLine("##@@&&");
	File.AddLine("#");

	If PartialExport Then
		File.AddLine("$$$ADD");
	Else
		File.AddLine("$$$CLR");
	EndIf;

	For Each Product IN Products Do
		
		If TypeOf(Product.Barcode) <> Type("Array") Then
			String = Format(Product.Code, "ND=13; NFD=0; NG=0")   + Delimiter + // Field 1
			Format(Product.Barcode, "ND=13; NFD=0; NG=0")         + Delimiter + // Field 2
			PrepareString(Product.DescriptionFull)                + Delimiter + // Field 3
			PrepareString(Product.Description)                    + Delimiter + // Field 4
			Format(Product.Price, "ND=15; NFD=2; NDS=.; NG=0")    + Delimiter + // Field 5
			Format(Product.Balance, "ND=17; NFD=3; NDS=.; NG=0")  + Delimiter + // Field 6
			"0"                                                   + Delimiter + // Field 7
			?(Product.WeightProduct, "1", "0")                    + Delimiter + // Field 8
			"0"                                                   + Delimiter + // Field 9
			"0"                                                   + Delimiter + // Field 10
			"0"                                                   + Delimiter + // Field 11
			?(Product.Property("SKU"), PrepareString(Product.SKU), "") + Delimiter + // Field 12
			"0"                                                   + Delimiter + // Field 13
			"0"                                                   + Delimiter + // Field 14
			"0"                                                   + Delimiter + // Field 15
			"0"                                                   + Delimiter + // Field 16
			"1";                                                               // Field 17
			File.AddLine(String);
		Else
			String = Format(Product.Code, "ND=13; NFD=0; NG=0") + Delimiter +  // Field 1
			Left(?(Product.Barcode.Count() = 0, "", Product.Barcode[0]), 13) + Delimiter + // Field 2
			PrepareString(Product.DescriptionFull)              + Delimiter + // Field 3
			PrepareString(Product.Description)                  + Delimiter + // Field 4
			Format(Product.Price, "ND=15; NFD=2; NDS=.; NG=0")  + Delimiter + // Field 5
			Format(Product.Balance, "ND=17; NFD=3; NG=0")       + Delimiter + // Field 6
			"0"                                                 + Delimiter + // Field 7
			?(Product.WeightProduct, "1", "0")                  + Delimiter + // Field 8
			"0"                                                 + Delimiter + // Field 9
			"0"                                                 + Delimiter + // Field 10
			"0"                                                 + Delimiter + // Field 11
			?(Product.Property("SKU"), PrepareString(Product.SKU), "") + Delimiter + // Field 12
			"0"                                                 + Delimiter + // Field 13
			"0"                                                 + Delimiter + // Field 14
			"0"                                                 + Delimiter + // Field 15
			"0"                                                 + Delimiter + // Field 16
			"1";                                                              // Field 17
			File.AddLine(String);

			// Import only additional barcodes.
			Counter = 0;
			For Each Barcode IN Product.Barcode Do
				// Skip the first barcode
				Counter = Counter + 1;
				If Counter = 1 Then
					Continue;
				EndIf;

				String ="# "+Format(Product.Code, "ND=13; NFD=0; NG=0")                + Delimiter +
									Left(Barcode, 13)                               + Delimiter +
									TrimAll(Product.DescriptionFull)                + Delimiter +
									TrimAll(Product.Description)	                    + Delimiter +
									Format(Product.Price, "ND=15; NFD=2; NDS=.; NG=0") + Delimiter +// Price
									""                                              + Delimiter +
									""                                              + Delimiter +
									""                                              + Delimiter +
									""                                              + Delimiter +
									?(TypeOf(Product.MeasurementUnit) = Type("String"), "", Product.MeasurementUnit.Factor);
				File.AddLine(String);
			EndDo;
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

EndFunction

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
//                                                  sold (returned) product.
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
	
	Result   = True;
	UnknownTransaction = False;
	
	Report = New Array;
	Receipts  = New Array;
	
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
		String = File.GetLine(1);
		If String = "#" Then
			IndexOf  = 4;
			String = File.GetLine(IndexOf);
			
			While True Do
				
				String = File.GetLine(IndexOf);
				
				If String = "#" Then
					IndexOf = IndexOf + 3;
					String =File.GetLine(IndexOf);
				EndIf;
				
				IndexOf = IndexOf + 1;
				If IsBlankString(String) Then
					Break;
				EndIf;
				String             = StrReplace(String, ";", Chars.LF);
				TransactionNoStr = StrGetLine(String, 1);
				DateTransactionStr  = StrGetLine(String, 2);
				TimeTransactionStr = StrGetLine(String, 3);
				DateTransactionStr  = StrReplace(DateTransactionStr,  ".", Chars.LF);
				TimeTransactionStr = StrReplace(TimeTransactionStr, ":", Chars.LF);
				DayStr            = StrGetLine(DateTransactionStr, 1);
				MonthStr           = StrGetLine(DateTransactionStr, 2);
				YearStr             = StrGetLine(DateTransactionStr, 3);
				HourStr             = StrGetLine(TimeTransactionStr, 1);
				MinuteStr          = StrGetLine(TimeTransactionStr, 2);
				SecondStr         = StrGetLine(TimeTransactionStr, 3);
				OperationKindStr   = StrGetLine(String, 4);
				KKMNumberStr        = StrGetLine(String, 5);
				ReceiptNumberStr       = StrGetLine(String, 6);
				CashierCodeStr      = StrGetLine(String, 7);
				Try
					ErrorField = NStr("en='Transaction number (1)';ru='Номер транзакции (1)'");
					TransactionNo = Number(TransactionNoStr);
					ErrorField = NStr("en='Transaction date (2,3)';ru='Дата транзакции (2,3)'");
					TransactionDate  = Date(Number(YearStr), Number(MonthStr), Number(DayStr),
					                       Number(HourStr), Number(MinuteStr), Number(SecondStr));
					ErrorField = NStr("en='Transaction type (4)';ru='Тип транзакции (4)'");
					OperationKind   = Number(OperationKindStr);
					ErrorField = NStr("en='Number KKM (5)';ru='Номер ККМ (5)'");
					CRNumber        = Number(KKMNumberStr);
					ErrorField = NStr("en='Number receipt (6)';ru='Номер чека (6)'");
					ReceiptNumber       = Number(ReceiptNumberStr);
				Except
					Output_Parameters.Add(999);
					Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to recognize the field:';ru='Неверный формат файла. Невозможно распознать поле:'") + Chars.NBSp + ErrorField);
					Result = False;
					Break;
				EndTry;
				
				If OperationKind = 1 Then
					// Registration without a product code.
					Output_Parameters.Add(999);
					Output_Parameters.Add(NStr("en='Sales registration ignoring the item codes is not available';ru='Регистрация продаж без учета кода товара не допускается'"));
					Result = False;
					Break;
					
				ElsIf OperationKind = 11 Then
					// Sale
					StrCode        = StrGetLine(String, 8);
					SectionStr     = StrGetLine(String, 9);
					PriceStr       = StrGetLine(String, 10);
					QuantityStr = StrGetLine(String, 11);
					AmountStr      = StrGetLine(String, 12);
					Try
						ErrorField = NStr("en='Product code (8)';ru='Код товара (8)'");
						Code        = Number(StrCode);
						ErrorField = NStr("en='Section (9)';ru='Секция (9)'");
						Section     = Number(SectionStr);
						ErrorField = NStr("en='Product price (10)';ru='Цена товара (10)'");
						Price       = Number(PriceStr);
						ErrorField = NStr("en='Products quantity (11)';ru='Количество товара (11)'");
						Quantity = Number(QuantityStr);
						ErrorField = NStr("en='Amount (12)';ru='Сумма (12)'");
						Amount      = Number(AmountStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to recognize the field:';ru='Неверный формат файла. Невозможно распознать поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					Product                 = New Structure("Code, Count, Price, Amount, Section, ReceiptNumber, TransactionNo");
					Product.Code             = Code;
					Product.Quantity      = Quantity;
					Product.Price            = Price;
					Product.Amount           = Amount;
					Product.Section          = Section;
					Product.ReceiptNumber       = ReceiptNumber;
					Product.TransactionNo = TransactionNo;
					Receipts.Add(Product);
					
				ElsIf OperationKind = 2 Then
					Output_Parameters.Add(999);
					Output_Parameters.Add(NStr("en='Reversing error';ru='Ошибка сторно'"));
					Result = False;
					Break;
						
				ElsIf OperationKind = 12 Then
					// ReversingEntry
					StrCode        = StrGetLine(String, 8);
					SectionStr     = StrGetLine(String, 9);
					PriceStr       = StrGetLine(String, 10);
					QuantityStr = StrGetLine(String, 11);
					AmountStr      = StrGetLine(String, 12);
					Try
						ErrorField = NStr("en='Product code (8)';ru='Код товара (8)'");
						Code        = Number(StrCode);
						ErrorField = NStr("en='Section (9)';ru='Секция (9)'");
						Section     = Number(SectionStr);
						ErrorField = NStr("en='Product price (10)';ru='Цена товара (10)'");
						Price       = Number(PriceStr);
						ErrorField = NStr("en='Products quantity (11)';ru='Количество товара (11)'");
						Quantity = Number(QuantityStr);
						ErrorField = NStr("en='Amount (12)';ru='Сумма (12)'");
						Amount      = Number(AmountStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					SearchStructure            = New Structure("Code, Price, Section, ReceiptNumber");
					SearchStructure.Code        = Code;
					SearchStructure.Price       = Price;
					SearchStructure.Section     = Section;
					SearchStructure.ReceiptNumber  = ReceiptNumber;
					Product                      = FindRows(Receipts, SearchStructure);
					If Product.Count() > 0 Then
						ItemNumber = Product[Product.Count() - 1].IndexInArray;
						Product = Receipts[ItemNumber];
						Product.Quantity = Product.Quantity + Quantity;
						Product.Amount      = Product.Amount + Amount;
						If Product.Quantity = 0 Or Product.Amount = 0 Then
							Receipts.Delete(ItemNumber);
						EndIf;
					Else
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Reversing error';ru='Ошибка сторно'"));
						Result = False;
						Break;
					EndIf;
					
				ElsIf OperationKind = 3 Or OperationKind = 4 Then
					Output_Parameters.Add(999);
					Output_Parameters.Add(NStr("en='Return error';ru='Ошибка возврата'"));
					Result = False;
					Break;
					
				ElsIf OperationKind = 13 Or OperationKind = 14 Then
					// Return
					StrCode        = StrGetLine(String, 8);
					SectionStr     = StrGetLine(String, 9);
					PriceStr       = StrGetLine(String, 10);
					QuantityStr = StrGetLine(String, 11);
					AmountStr      = StrGetLine(String, 12);
					Try
						ErrorField = NStr("en='Product code (8)';ru='Код товара (8)'");
						Code        = Number(StrCode);
						ErrorField = NStr("en='Section (9)';ru='Секция (9)'");
						Section     = Number(SectionStr);
						ErrorField = NStr("en='Product price (10)';ru='Цена товара (10)'");
						Price       = Number(PriceStr);
						ErrorField = NStr("en='Products quantity (11)';ru='Количество товара (11)'");
						Quantity = Number(QuantityStr);
						ErrorField = NStr("en='Amount (12)';ru='Сумма (12)'");
						Amount      = Number(AmountStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					Product                 = New Structure("Code, Count, Price, Amount, Section, ReceiptNumber, TransactionNo");
					Product.Code             = Code;
					Product.Quantity      = Quantity;
					Product.Price            = Price;
					Product.Amount           = Amount;
					Product.Section          = Section;
					Product.ReceiptNumber       = ReceiptNumber;
					Product.TransactionNo = TransactionNo;
					Receipts.Add(Product);
					
				ElsIf OperationKind = 24 Then
					// Measurement unit recording.
				ElsIf OperationKind = 30 Then
					// Price editing
				ElsIf OperationKind = 15 Or OperationKind = 17 Then
					// Final discount for the position
					StrCode        = StrGetLine(String, 8);
					SectionStr     = StrGetLine(String, 9);
					DiscountStr     = StrGetLine(String, 11);
					AmountStr      = StrGetLine(String, 12);
					Try
						ErrorField = NStr("en='Product code (8)';ru='Код товара (8)'");
						Code        = Number(StrCode);
						ErrorField = NStr("en='Section (9)';ru='Секция (9)'");
						Section     = Number(SectionStr);
						ErrorField = NStr("en='Discount (11)';ru='Скидка (11)'");
						Discount     = Number(DiscountStr);
						ErrorField = NStr("en='Amount (12)';ru='Сумма (12)'");
						Amount      = Number(AmountStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					SearchStructure            = New Structure("Code, Section, ReceiptNumber");
					SearchStructure.Code        = Code;
					SearchStructure.Section     = Section;
					SearchStructure.ReceiptNumber  = ReceiptNumber;
					Product                      = FindRows(Receipts, SearchStructure);
					If Product.Count() > 0 Then
						ItemNumber = Product[Product.Count() - 1].IndexInArray;
						Product = Receipts[ItemNumber];
						If Product.Amount > 0 Then
							Product.Amount = Product.Amount - Max(Amount, -Amount);
						Else
							Product.Amount = Product.Amount + Max(Amount, -Amount);
						EndIf;
					Else
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Error of the total discount for position';ru='Ошибка итоговой скидки на позицию'"));
						Result = False;
						Break;
					EndIf;
					
				ElsIf OperationKind = 16 Or OperationKind = 18 Then
					// Final increment for the position.
					StrCode        = StrGetLine(String, 8);
					SectionStr     = StrGetLine(String, 9);
					MarkupStr   = StrGetLine(String, 11);
					AmountStr      = StrGetLine(String, 12);
					Try
						ErrorField = NStr("en='Product code (8)';ru='Код товара (8)'");
						Code        = Number(StrCode);
						ErrorField = NStr("en='Section (9)';ru='Секция (9)'");
						Section     = Number(SectionStr);
						ErrorField = NStr("en='Markup (11)';ru='Надбавка (11)'");
						Markup   = Number(MarkupStr);
						ErrorField = NStr("en='Amount (12)';ru='Сумма (12)'");
						Amount      = Number(AmountStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					SearchStructure            = New Structure("Code, Section, ReceiptNumber");
					SearchStructure.Code        = Code;
					SearchStructure.Section     = Section;
					SearchStructure.ReceiptNumber  = ReceiptNumber;
					Product                      = FindRows(Receipts, SearchStructure);
					If Product.Count() > 0 Then
						ItemNumber = Product[Product.Count() - 1].IndexInArray;
						Product = Receipts[ItemNumber];
						If Product.Amount > 0 Then
							Product.Amount = Product.Amount + Max(Amount, -Amount);
						Else
							Product.Amount = Product.Amount - Max(Amount, -Amount);
						EndIf;
					Else
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Error of the total markup for position';ru='Ошибка итоговой надбавки на позицию'"));
						Result = False;
						Break;
					EndIf;
					
				ElsIf OperationKind = 70 Or OperationKind = 71 Then
					// Discount details
				ElsIf OperationKind = 40 Then
					// Payment
				ElsIf OperationKind = 50 Then
					// Deposit
				ElsIf OperationKind = 51 Then
					// Payment
				ElsIf OperationKind = 55 Then
					// Closing receipt
				ElsIf OperationKind = 56 Then
					// Receipt cancel
					SearchStructure           = New Structure("ReceiptNumber");
					SearchStructure.ReceiptNumber = ReceiptNumber;
					Products                    = FindRows(Receipts, SearchStructure);
					LineCount           = Products.Count();
					For DelRow = 1 To LineCount Do
						Receipts.Delete(Products[LineCount - DelRow].IndexInArray);
					EndDo;
				ElsIf OperationKind = 58 Then
					// Deferred receipt
				ElsIf OperationKind = 59 Then
					// Deferred receipt continued.
				ElsIf OperationKind = 64 Then
					// Print sales receipt
				ElsIf OperationKind = 65 Then
					// Open cash drawer
				ElsIf OperationKind = 66 Then
					// Product view
				ElsIf OperationKind = 67 Then
					// Discount card view
				ElsIf OperationKind = 80 Then
					// Return based on the receipt number
					PositionTransactionStr      = StrGetLine(String, 11);
					ReturnedReceiptNumberStr = StrGetLine(String, 12);
					Try
						ErrorField = NStr("en='Transaction of the position (11)';ru='Транзакция позиции (11)'");
						PositionTransaction      = Number(PositionTransactionStr);
						ErrorField = NStr("en='Number of the returned receipt (12)';ru='Номер возвращаемого чека (12)'");
						ReturnedReceiptNumber = Number(ReturnedReceiptNumberStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					SearchStructure                 = New Structure("ReceiptNumber");
					SearchStructure.ReceiptNumber       = ReturnedReceiptNumber;
					Temp                            = FindRows(Receipts, SearchStructure);
					LineCount                 = Temp.Count() - 1;
					If LineCount >= 0 Then
						For DelRow = 0 To LineCount Do
							Product = New Structure("Code, Count, Price, Amount, Section, ReceiptNumber, TransactionNo");
							Product.Code             = Temp[DelRow].Code;
							Product.Quantity      = -Temp[DelRow].Quantity;
							Product.Price            = Temp[DelRow].Price;
							Product.Amount           = -Temp[DelRow].Amount;
							Product.Section          = Temp[DelRow].Section;
							Product.ReceiptNumber       = ReceiptNumber;
							Product.TransactionNo = TransactionNo;
							Receipts.Add(Product);
						EndDo;
					Else
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Error of return by receipt number';ru='Ошибка возврата по номеру чека'"));
						Result = False;
						Break;
					EndIf;
					
				ElsIf OperationKind = 35 Then
					// Amount discount for the receipt
					DiscountAmountStr = StrGetLine(String, 11);
					Try
						ErrorField  = NStr("en='Discount amount (11)';ru='Сумма скидки (11)'");
						DiscountAmount = Number(DiscountAmountStr);
						DiscountAmount = Max(DiscountAmount, -DiscountAmount);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					
					SearchStructure           = New Structure("ReceiptNumber");
					SearchStructure.ReceiptNumber = ReceiptNumber;
					Products                    = FindRows(Receipts, SearchStructure);
					SumCheck                 = 0;
					
					For Each Product IN Products Do
						SumCheck = SumCheck + Receipts[Product.IndexInArray].Amount;
					EndDo;
					
					DiscountPercent = DiscountAmount / SumCheck * 100;
					For Each Product IN Products Do
						If Product.IndexInArray = Products.Count() - 1 Then
							TempDiscount = DiscountAmount;
						Else
							TempDiscount = Round(Receipts[Product.IndexInArray].Amount / 100 * DiscountPercent, 2);
							DiscountAmount = DiscountAmount - TempDiscount;
						EndIf;
						Receipts[Product.IndexInArray].Amount = Receipts[Product.IndexInArray].Amount - TempDiscount; 
					EndDo;
					              
				ElsIf OperationKind = 36 Then
					// Sum increment for the receipt
					AmountSurchargesStr = StrGetLine(String, 11);
					Try
						ErrorField    = NStr("en='Increment amount (11)';ru='Сумма надбавки (11)'");
						AmountSurcharges = Number(AmountSurchargesStr);
						AmountSurcharges = Max(AmountSurcharges, -AmountSurcharges);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					
					SearchStructure           = New Structure("ReceiptNumber");
					SearchStructure.ReceiptNumber = ReceiptNumber;
					Products                    = FindRows(Receipts, SearchStructure);
					SumCheck                 = 0;
					
					For Each Product IN Products Do
						SumCheck = SumCheck + Receipts[Product.IndexInArray].Amount;
					EndDo;
					
					MarkupPercent = AmountSurcharges / SumCheck * 100;
					For Each Product IN Products Do
						If Product.IndexInArray = Products.Count() - 1 Then
							TempPremium = AmountSurcharges;
						Else
							TempPremium  = Round(Receipts[Product.IndexInArray].Amount / 100 * MarkupPercent, 2);
							AmountSurcharges = AmountSurcharges - TempPremium;
						EndIf;
						Receipts[Product.IndexInArray].Amount = Receipts[Product.IndexInArray].Amount + TempPremium; 
					EndDo;
					
				ElsIf OperationKind = 37 Then
					// Percent discount for the receipt
					DiscountPercentStr = StrGetLine(String, 11);
					Try
						ErrorField = NStr("en='Discount percent (11)';ru='Процент скидки (11)'");
						DiscountPercent = Number(DiscountPercentStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					SearchStructure           = New Structure("ReceiptNumber");
					SearchStructure.ReceiptNumber = ReceiptNumber;
					Product                     = FindRows(Receipts, SearchStructure);
					For Each Temp IN Product Do
						Receipts[Temp.IndexInArray].Amount = Receipts[Temp.IndexInArray].Amount * (100 - DiscountPercent) / 100;
					EndDo;
					
				ElsIf OperationKind = 38 Then
					// Percent increment for the receipt.
					MarkupPercentStr = StrGetLine(String, 11);
					Try
						ErrorField = NStr("en='Markup percent (11)';ru='Процент надбавки (11)'");
						MarkupPercent = Number(MarkupPercentStr);
					Except
						Output_Parameters.Add(999);
						Output_Parameters.Add(NStr("en='Incorrect file format. Impossible to convert field to the number:';ru='Неверный формат файла. Невозможно преобразовать к числу поле:'") + Chars.NBSp + ErrorField);
						Result = False;
						Break;
					EndTry;
					SearchStructure           = New Structure("ReceiptNumber");
					SearchStructure.ReceiptNumber = ReceiptNumber;
					Product                     = FindRows(Receipts, SearchStructure);
					For Each Temp IN Product Do
						Receipts[Temp.IndexInArray].Amount = Receipts[Temp.IndexInArray].Amount * (100 + MarkupPercent) / 100;
					EndDo;
				ElsIf OperationKind = 60 Or OperationKind = 61 Or OperationKind = 62 Or OperationKind = 63 Then
					// Reports
				ElsIf OperationKind = 75 Then
					// Taxes
				ElsIf OperationKind = 90 Or OperationKind = 91 Then
					// Seller information
				ElsIf OperationKind = 150 Or OperationKind = 151 Or OperationKind = 152 Or OperationKind = 153 Or OperationKind = 155 Then				
					// Start the application, Payment using the payment system, Return using the payment system,
					// Cancel using the payment system, Authorization.
				ElsIf OperationKind = 140 Then
					// Cashless payment parameters.
				Else
					ErrorDescription = NStr("en='Unknown transaction has been detected: %OperationKind%. Data by transaction has not been imported!';ru='Обнаружена неизвестная транзакция: %ТипТранзакции%. Данные по транзакции не были загружены!'");
					CommonUseClientServer.MessageToUser(StrReplace(ErrorDescription, "%OperationKind%", String(OperationKind)));
					UnknownTransaction = True;
					Continue; // Unknown transaction (continue iteration).
				EndIf;
			EndDo;
			
			If UnknownTransaction Then
				CommonUseClientServer.MessageToUser(NStr("en='Not all data has been exported from the report. Contact the system administrator!';ru='Не все данные были загружены из отчета. Обратитесь к администратору системы!'"));
			EndIf;
			
		ElsIf String = "@" Then
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Operation is aborted. The report was already loaded!';ru='Операция прервана. Отчет уже был загружен!'"));
			Result = False;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(NStr("en='Incorrect data format or data is absent.';ru='Неверный формат данных или данные отсутствуют.'"));
			Result = False;
		EndIf;
	EndIf;

	For Each curRow IN Receipts Do
		curRow.Insert("Discount", 0);
	EndDo;
	Output_Parameters.Add(Receipts);

	Return Result;

EndFunction

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
		IndexOf  = 1;
		While True Do
			String = Document.GetLine(IndexOf);
			If IsBlankString(String) Then
				Break;
			EndIf;
			If String = "#" Then
				Document.ReplaceLine(IndexOf, "@");
			EndIf;
			IndexOf = IndexOf + 1;
		EndDo;
		Document.Write(Parameters.ReportFile, TextEncoding.ANSI);
	Except
	EndTry;
		
	Return Result;
	
EndFunction

// The function clears products in the cash register Offline.
//
Function ClearProductsOnCR(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 

	Result = True;

	File = New TextDocument();

	File.AddLine("##@@&&");
	File.AddLine("#");

	File.AddLine("$$$CLR");

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

EndFunction

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