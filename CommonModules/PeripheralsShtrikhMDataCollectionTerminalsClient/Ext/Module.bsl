
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
	Port            = Undefined;
	Speed        = Undefined;
	Timeout         = Undefined;
	Parity        = Undefined;
	DataBits      = Undefined;
	StopBits        = Undefined;
	ExportingTable = Undefined;
	ImportingTable = Undefined;
	ExportFormat  = Undefined;
	ImportFormat = Undefined;
	Model          = Undefined;
	Description    = Undefined;

	Parameters.Property("Port"           , Port);
	Parameters.Property("Speed"       , Speed);
	Parameters.Property("Timeout"        , Timeout);
	Parameters.Property("Parity"       , Parity);
	Parameters.Property("DataBits"     , DataBits);
	Parameters.Property("StopBits"       , StopBits);
	Parameters.Property("ExportingTable", ExportingTable);
	Parameters.Property("ImportingTable", ImportingTable);
	Parameters.Property("ExportFormat" , ExportFormat);
	Parameters.Property("ImportFormat" , ImportFormat);
	Parameters.Property("Model"         , Model);

	If Port            = Undefined
	 Or Speed        = Undefined
	 Or Timeout         = Undefined
	 Or Parity        = Undefined
	 Or DataBits      = Undefined
	 Or StopBits        = Undefined
	 Or ExportingTable = Undefined
	 Or ImportingTable = Undefined
	 Or ExportFormat  = Undefined
	 Or ImportFormat  = Undefined
	 Or Model          = Undefined Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.'"));

		Result = False;
	EndIf;

	If Result Then
		DriverObject.AddDevice();
		If DriverObject.ErrorCode = 0 Then
			ConnectionParameters.DeviceID    = DriverObject.CurrentDeviceNumber;
			DriverObject.NumberPort            = Parameters.Port;
			DriverObject.ExchangeSpeed        = Parameters.Speed;
			DriverObject.Timeout               = Parameters.Timeout;
			DriverObject.Parity              = Parameters.Parity;
			DriverObject.DataBits            = Parameters.DataBits;
			DriverObject.StopBits              = Parameters.StopBits;
			DriverObject.NameCurrentDevice = Parameters.Model;

			DriverObject.DeviceIsOn = 1;
			If DriverObject.Result <> 0 Then
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				DriverObject.DeleteDevice();

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

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;
	DriverObject.DeviceIsOn = 0;
	DriverObject.DeleteDevice();

	Return Result;

EndFunction

// The function receives, processes and redirects for execution a command to the driver.
//
Function RunCommand(Command, InputParameters = Undefined, Output_Parameters = Undefined,
                         DriverObject, Parameters, ConnectionParameters) Export

	Result = True;

	Output_Parameters = New Array();

	// Exporting table to the device.
	If Command = "ImportDirectory" Then
		ExportingTable = InputParameters[1];

		Result = ExportTable(DriverObject, Parameters, ConnectionParameters,
									 ExportingTable, Output_Parameters);

	// Importing table from the device.
	ElsIf Command = "ExportDocument" Then
		Result = Import_Table(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Test device
	ElsIf Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

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

// Function exports the row into data collection terminal.
//
Function ExportTable(DriverObject, Parameters, ConnectionParameters, ExportingTable, Output_Parameters)

	Result = True;

	Result = BeginUnloading(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	If Result Then
		DriverObject.ShowProgress = True;
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
		EndDo;
		DriverObject.ShowProgress = False;

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
		Output_Parameters.Add(New Array());
		For IndexOf = 1 To Quantity Do
			Result = ImportString(DriverObject, Parameters, ConnectionParameters,
			                            Barcode, Quantity, Output_Parameters);
			If Result Then
				Output_Parameters[0].Add(Barcode);
				Output_Parameters[0].Add(Quantity);
			Else
				FinishImport(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
				Break;
			EndIf;
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

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;

	DriverObject.NumberForms = Parameters.ExportingTable;
	If DriverObject.ClearBufferOfTable() = 0 Then
		If DriverObject.StartImportingTable() <> 0 Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);

			Result = False;
		EndIf;
	Else
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	EndIf;

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

	DataForExportings = New Array();
	If Parameters.ExportFormat.Count() > 0 Then
		For Each FormatRow IN Parameters.ExportFormat Do
			If FormatRow.Description = "Barcode" Then
				DataForExportings.Add(Barcode);
			ElsIf FormatRow.Description = "ProductsAndServices" Then
				DataForExportings.Add(ProductsAndServices);
			ElsIf FormatRow.Description = "MeasurementUnit" Then
				DataForExportings.Add(MeasurementUnit);
			ElsIf FormatRow.Description = "ProductsAndServicesCharacteristic" Then
				DataForExportings.Add(ProductsAndServicesCharacteristic);
			ElsIf FormatRow.Description = "ProductsAndServicesSeries" Then
				DataForExportings.Add(ProductsAndServicesSeries);
			ElsIf FormatRow.Description = "Quality" Then
				DataForExportings.Add(Quality);
			ElsIf FormatRow.Description = "Price" Then
				DataForExportings.Add(Price);
			ElsIf FormatRow.Description = "Quantity" Then
				DataForExportings.Add(Quantity);
			EndIf;
		EndDo;
	Else
		DataForExportings.Add(Barcode);
		DataForExportings.Add(ProductsAndServices);
		DataForExportings.Add(MeasurementUnit);
		DataForExportings.Add(ProductsAndServicesCharacteristic);
		DataForExportings.Add(ProductsAndServicesSeries);
		DataForExportings.Add(Quality);
		DataForExportings.Add(Price);
		DataForExportings.Add(Quantity);
	EndIf;

	If DataForExportings.Count() > 0 Then
		For Each Data IN DataForExportings Do
			Response = DriverObject.AddToTable(Data);
			If Response <> 0 Then
				Break;
			EndIf;
		EndDo;
	EndIf;

	If DriverObject.Result <> 0 Then
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

	Response = DriverObject.Import_Table();
	If Response <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// Function prepares the export of data from the data collection terminal procedure.
//
Function StartImport(DriverObject, Parameters, ConnectionParameters, Quantity, Output_Parameters)

	Result = True;

	DriverObject.CurrentDeviceNumber = ConnectionParameters.DeviceID;

	DriverObject.NumberForms = Parameters.ImportingTable;
	Quantity                = DriverObject.GetRecordsCount();
	If DriverObject.Result = 0 Then
		If DriverObject.ClearBufferOfTable() = 0 Then
			If DriverObject.BeginReport() <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);

				Result = False;
			EndIf;
		Else
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);

			Result = False;
		EndIf;
	Else
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

	Result  = True;
	Barcode   = Undefined;
	Quantity = Undefined;

	DriverObject.GetRecord();
	If DriverObject.Result = 0 Then
		If Parameters.ImportFormat.Count() > 0 Then
			For Each FormatRow IN Parameters.ImportFormat Do
				If FormatRow.Description = "Barcode" Then
					Barcode = DriverObject["Field" + FormatRow.FieldNumber];
				ElsIf FormatRow.Description = "Quantity" Then
					Quantity = DriverObject["Field" + FormatRow.FieldNumber];
				EndIf;
			EndDo;
		Else
			Barcode   = DriverObject["Field1"];
			Quantity = DriverObject["Field2"];
		EndIf;
	Else
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
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

	DriverObject.EndReport();
	If DriverObject.Result <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);

		Result = False;
	EndIf;

	Return Result;

EndFunction

// Function tests device.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Result = ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	Output_Parameters.Add(?(Result, 0, 999));
	Output_Parameters.Add(?(Result, "", NStr("en='An error occurred while connecting the device'")));

	DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	Return Result;

EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed'"));
	Output_Parameters.Add(NStr("en='Not defined'"));

	Try
		Output_Parameters[1] = DriverObject.Version;
	Except
	EndTry;

	Return Result;

EndFunction

#EndRegion