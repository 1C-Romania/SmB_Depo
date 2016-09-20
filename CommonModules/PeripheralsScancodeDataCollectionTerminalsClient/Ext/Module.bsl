
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

	Result = True;
	ConnectionParameters.Insert("DeviceID", "");

	Output_Parameters = New Array();

	// Check device parameters.
	Port                     = Undefined;
	Speed                 = Undefined;
	Timeout                  = Undefined;
	IRStand              = Undefined;
	BaseSeparator          = Undefined;
	DocumentSeparator     = Undefined;
	NumberBase                = Undefined;
	DocumentNumber           = Undefined;
	ToClearDocument          = Undefined;
	BaseFormat               = Undefined;
	DocumentFormat          = Undefined;
	Model                   = Undefined;
	ImportingSource         = Undefined;
	
	Parameters.Property("Port"                    , Port);
	Parameters.Property("Speed"                , Speed);
	Parameters.Property("Timeout"                 , Timeout);
	Parameters.Property("IRStand"             , IRStand);
	Parameters.Property("BaseSeparator"         , BaseSeparator);
	Parameters.Property("DocumentSeparator"    , DocumentSeparator);
	Parameters.Property("NumberBase"               , NumberBase);
	Parameters.Property("DocumentNumber"          , DocumentNumber);
	Parameters.Property("ToClearDocument"         , ToClearDocument);
	Parameters.Property("BaseFormat"              , BaseFormat);
	Parameters.Property("DocumentFormat"         , DocumentFormat);
	Parameters.Property("Model"                  , Model);
	Parameters.Property("ImportingSource"        , ImportingSource);
	
	If Port                     = Undefined
	 Or Speed                 = Undefined
	 Or Timeout                  = Undefined
	 Or IRStand              = Undefined
	 Or BaseSeparator          = Undefined
	 Or DocumentSeparator     = Undefined
	 Or NumberBase                = Undefined
	 Or DocumentNumber           = Undefined
	 Or ToClearDocument          = Undefined
	 Or BaseFormat               = Undefined
	 Or DocumentFormat          = Undefined
	 Or Model                   = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.';ru='Не настроены параметры устройства.
		|Для корректной работы устройства необходимо задать параметры его работы.
		|Сделать это можно при помощи формы
		|""Настройка параметров"" модели подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));

		Result = False;
	EndIf;

	If Result Then
		Response = DriverObject.SetParameters(Parameters.Port,
		                                           Parameters.Speed,
		                                           ?(Parameters.IRStand, 1, 0),
		                                           Char(Parameters.BaseSeparator),
		                                           Char(Parameters.DocumentSeparator));

		If Response = 1 Then
			DriverObject.SetDelay(Parameters.Timeout);
			DriverObject.Connect();
			If DriverObject.Result <> 0 Then
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;
			EndIf;
		Else
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);
			Result = False;
		EndIf;
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

	Output_Parameters = New Array();

	DriverObject.Disable();

	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Exporting table to the device.
	If Command = "ExportTable" OR Command = "ImportDirectory" Then
		ExportingTable = InputParameters[1];

		Result = ExportTable(DriverObject, Parameters, ConnectionParameters,
		                             ExportingTable, Output_Parameters);

	// Importing table from the device.
	ElsIf Command = "Import_Table" OR Command = "ExportDocument" Then
		Result = Import_Table(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
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

// Function exports the row into data collection terminal.
//
Function ExportTable(DriverObject, Parameters, ConnectionParameters, ExportingTable, Output_Parameters)

	Result = True;
	
	If ExportingTable.Count() = 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='There is no data to export.';ru='Нет данных для выгрузки.'"));
		Return False;
	EndIf;
	
	Result = BeginUnloading(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	If Result Then
		
		CurrentPercent = 0;
		PercentIncrement = 100 / ExportingTable.Count();
		
		For IndexOf = 0 To ExportingTable.Count() - 1 Do
			Result = DumpLine(DriverObject, Parameters, ConnectionParameters,
			                            ExportingTable[IndexOf][0].Value, ExportingTable[IndexOf][1].Value,
			                            ExportingTable[IndexOf][2].Value, ExportingTable[IndexOf][3].Value,
			                            ExportingTable[IndexOf][4].Value, ExportingTable[IndexOf][5].Value,
			                            ExportingTable[IndexOf][6].Value, ExportingTable[IndexOf][7].Value,
			                            Output_Parameters);
			If Not Result Then
				FinishExport(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
				Break;
			EndIf;
			
			CurrentPercent = CurrentPercent + PercentIncrement;
			Status(NStr("en='Exporting data ...';ru='Выгрузка данных...'"), Round(CurrentPercent));
		EndDo;
		
		If Result Then
			Result = FinishExport(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function imports the row from data collection terminal.
//
Function Import_Table(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result  = True;
	Barcode   = Undefined;
	Quantity = Undefined;

	Result = StartImport(DriverObject, Parameters, ConnectionParameters, Quantity, Output_Parameters);

	If Result Then
		
		CurrentPercent = 0;
		PercentIncrement = 100 / Quantity;
		
		Output_Parameters.Add(New Array());
		
		For IndexOf = 1 To Quantity Do
			Result = ImportString(DriverObject, Parameters, ConnectionParameters,
			                            Barcode, Quantity, Output_Parameters);
			If Result Then
				Output_Parameters[0].Add(Barcode);
				Output_Parameters[0].Add(Quantity);
			Else
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);

				FinishImport(DriverObject, Parameters, ConnectionParameters, New Array());

				Result = False;
				Break;
			EndIf;
			
			CurrentPercent = CurrentPercent + PercentIncrement;
			Status(NStr("en='Importing data...';ru='Выполняется загрузка данных...'"), Round(CurrentPercent));
		EndDo;
		
	EndIf;

	If Result Then
		Result = FinishImport(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		If Not Result Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);

			Result = False;
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function prepares the data export to terminal procedure.
//
Function BeginUnloading(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Return Result;

EndFunction

// Function exports the row into data collection terminal.
//
// Parameters:
//  Object                         - <*>
//                                 - Driver object of the trading equipment.
//
//  Barcode                       - <String>
//                                 - Product barcode.
//
//  ProductsAndServices                   - <CatalogRef.ProductsAndServices>
//                                 - ProductsAndServices.
//
//  MeasurementUnit               - <CatalogRef.UOM>
//                                 - Measurement unit of products and services.
//
//  ProductsAndServicesCharacteristic     - <CatalogRef.ProductsAndServicesCharacteristics>
//                                 - Products and services characteristic.
//
//  ProductsAndServicesSeries              - <CatalogRef.ProductsAndServicesSeries>
//                                 - Products and services series.
//
//  Quality                       - <CatalogRef.Quality>
//                                 - Quality.
//
//  Price                           - <Number>
//                                 - Products and services price.
//
//  Quantity                     - <Number>
//                                 - Products and services number.
//
// Returns:
//  <EnumRef.ErrorDetails*> - Result of the function work.
//
Function DumpLine(DriverObject, Parameters, ConnectionParameters,
                        Barcode, ProductsAndServices, MeasurementUnit,
                        ProductsAndServicesCharacteristic, ProductsAndServicesSeries,
                        Quality, Price, Quantity, Output_Parameters) Export

	Result = True;

	For IndexOf = 1 To 8 Do
		DriverObject["Field" + IndexOf] = "";
	EndDo;
	
	// Croping of the "Products and services" field is associated with the TSD tasks settings with the name consisitng of 40 characters by default.
	
	If Parameters.BaseFormat.Count() > 0 Then
		For Each FormatRow IN Parameters.BaseFormat Do
			If FormatRow.Description = "Barcode" Then
				DriverObject["Field" + FormatRow.FieldNumber] = Barcode;
			ElsIf FormatRow.Description = "ProductsAndServices" Then
				DriverObject["Field" + FormatRow.FieldNumber] = Left(ProductsAndServices, 40);
			ElsIf FormatRow.Description = "MeasurementUnit" Then
				DriverObject["Field" + FormatRow.FieldNumber] = MeasurementUnit;
			ElsIf FormatRow.Description = "ProductsAndServicesCharacteristic" Then
				DriverObject["Field" + FormatRow.FieldNumber] = ProductsAndServicesCharacteristic;
			ElsIf FormatRow.Description = "ProductsAndServicesSeries" Then
				DriverObject["Field" + FormatRow.FieldNumber] = ProductsAndServicesSeries;
			ElsIf FormatRow.Description = "Quality" Then
				DriverObject["Field" + FormatRow.FieldNumber] = Quality;
			ElsIf FormatRow.Description = "Price" Then
				DriverObject["Field" + FormatRow.FieldNumber] = Format(Price, "NG=0");
			ElsIf FormatRow.Description = "Quantity" Then
				DriverObject["Field" + FormatRow.FieldNumber] = Format(Quantity, "NG=0");
			EndIf;
		EndDo;
	Else
		DriverObject.Field1 = Barcode;
		DriverObject.Field2 = Left(ProductsAndServices, 40);
		DriverObject.Field3 = MeasurementUnit;
		DriverObject.Field4 = ProductsAndServicesCharacteristic;
		DriverObject.Field5 = ProductsAndServicesSeries;
		DriverObject.Field6 = Quality;
		DriverObject.Field7 = Format(Price, "NG=0");
		DriverObject.Field8 = Format(Quantity, "NG=0");
	EndIf;

	Response = DriverObject.ImportWrite(Parameters.NumberBase);
	If Response = 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// Function completes the export of data into data collection terminal procedure.
//
Function FinishExport(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.FinishImport();

	Return Result;

EndFunction

// Function prepares the export of data from the data collection terminal procedure.
//
Function StartImport(DriverObject, Parameters, ConnectionParameters, Quantity, Output_Parameters)

	Result = True;
	ConnectionParameters.Insert("LastImportingSource", ?(Parameters.ImportingSource = Undefined, "Document", Parameters.ImportingSource));
	
	If ConnectionParameters.LastImportingSource = "Document" Then
		Quantity = DriverObject.RecordsInDocument(Parameters.DocumentNumber);
	Else
		Quantity = DriverObject.RecordsInBaseData(Parameters.NumberBase);
	EndIf;
	
	If Quantity = 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='No data to export from the data collection terminal.';ru='Отсутствуют данные для загрузки из терминала сбора данных.'"));
		Result = False;
	ElsIf Quantity < 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

// Function imports the row from data collection terminal.
//
// Parameters:
//  Object                         - <*>
//                                 - Driver object of the trading equipment.
//
//  Barcode                       - <String>
//                                 - Barcode which corresponds to these products and services.
//
//  Quantity                     - <Number>
//                                 - Output parameter; quantity of Products and services.
//
// Returns:
//  <EnumRef.ErrorDetails*> - Result of the function work.
//
Function ImportString(DriverObject, Parameters, ConnectionParameters, Barcode, Quantity, Output_Parameters)

	Result       = True;
	SourceFormat = ?(ConnectionParameters.LastImportingSource = "Document",
	                    Parameters.DocumentFormat, Parameters.BaseFormat);
	Barcode        = Undefined;
	Quantity      = Undefined;
	Delimiter = "";
	
	If ConnectionParameters.LastImportingSource = "Document" Then
		Delimiter = Char(Parameters.DocumentSeparator);
		DriverObject.GetDocumentOfRecord(Parameters.DocumentNumber);
	Else
		Delimiter = Char(Parameters.BaseSeparator);
		DriverObject.GetRecordFromDataBase(Parameters.NumberBase);
	EndIf;
	
	If DriverObject.Result <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	Else
		DataFromTSD = StrReplace(DriverObject.Data, Delimiter, Chars.LF);

		If SourceFormat.Count() > 0 Then
			For Each FormatRow IN SourceFormat Do
				If FormatRow.Description = "Barcode" Then
					Try
						#If WebClient Then
							Barcode = StrGetLine(DataFromTSD, FormatRow.FieldNumber);
						#Else
							Barcode = DriverObject["Field" + FormatRow.FieldNumber];
						#EndIf
					Except
						Continue;
					EndTry;
				ElsIf FormatRow.Description = "Quantity" Then
					Try
						#If WebClient Then
							Quantity = Number(StrGetLine(DataFromTSD, FormatRow.FieldNumber));
						#Else
							Quantity = Number(DriverObject["Field" + FormatRow.FieldNumber]);
						#EndIf
					Except
						Quantity = 0;
					EndTry;
				EndIf;
			EndDo;
		Else
			Barcode   = DriverObject.Field1;
			Try
				If ConnectionParameters.LastImportingSource = "Document" Then
					Try
						Quantity = Number(DriverObject.Field2);
					Except
						Quantity = 0;
					EndTry;
				Else
					Try
						Quantity = Number(DriverObject.Field8);
					Except
						Quantity = 0;
					EndTry;
				EndIf;
			Except
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(NStr("en='Incorrect data format of the ""Quantity"" field.
		|Check the terminal task setup.';ru='Неверный формат данных поля ""Количество"".
		|Проверьте настройку задачи терминала.'"));

				Result = False;
			EndTry;
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function ends the procedure of exporting data from the data collection terminal.
//
// Parameters:
//  Object                         - <*>
//                                 - Driver object of the trading equipment.
//
// Returns:
//  <EnumRef.ErrorDetails*> - Result of the function work.
//
Function FinishImport(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	DriverObject.FinishImport();

	If DriverObject.Result <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);
		Result = False;
	Else
		If Parameters.ToClearDocument
		   AND ConnectionParameters.LastImportingSource = "Document" Then
			DriverObject.ClearDocument(Parameters.DocumentNumber);
			If DriverObject.Result <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;
			EndIf;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
	Output_Parameters.Add(NStr("en='Not defined';ru='Не определена'"));

	Try
		Output_Parameters[1] = DriverObject.GetVersionNumber();
	Except
	EndTry;

	Return Result;

EndFunction

// The function withdraws the report without clearance.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;
	
	DriverObject.Port                 = Parameters.Port;
	DriverObject.Speed             = Parameters.Speed;
	DriverObject.Delay             = Parameters.Timeout;
	DriverObject.IR                   = Parameters.IRStand;
	DriverObject.BaseSeparator      = Parameters.BaseSeparator;
	DriverObject.DocumentSeparator = Parameters.DocumentSeparator;
	
	DriverObject.DeviceTest();
	
	Return Result;
	
EndFunction

#EndRegion