
#Region ProgramInterface

// Function connects a device.
//
Function ConnectDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Result = True;
	ConnectionParameters.Insert("DeviceID", "");
	
	Output_Parameters 	= New Array();
	
	Interface	 		= Undefined;
	Port         		= Undefined;
	Speed     		= Undefined;
	Timeout      		= Undefined;
	IPAddress      		= Undefined;
    UDPReceiverPort 	= Undefined;
    UDPTimeout  		= Undefined;
	Password              = Undefined;
	QuickImport		= Undefined;

    Parameters.Property("Interface"			, Interface);
    Parameters.Property("Port"				, Port);
    Parameters.Property("Speed"			, Speed);
    Parameters.Property("Timeout"			, Timeout);
    Parameters.Property("IPAddress"			, IPAddress);
    Parameters.Property("UDPReceiverPort"	, UDPReceiverPort);
    Parameters.Property("UDPTimeout"			, UDPTimeout);
    Parameters.Property("Password"				, Password);
    Parameters.Property("QuickImport"	, QuickImport);
  

	If Interface			= Undefined           
	 Or Port				= Undefined
	 Or Speed			= Undefined		
	 Or Timeout			= Undefined
	 Or IPAddress			= Undefined
	 Or UDPReceiverPort	= Undefined
	 Or UDPTimeout			= Undefined 
	 Or Password				= Undefined
	 Then
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device parameters are not set.
		|For the correct work of the device it is necessary to specify the parameters of its work.
		|You can do it using the Parameters setting
		|form of the peripheral model in the Connection and equipment setting form.';ru='Не настроены параметры устройства.
		|Для корректной работы устройства необходимо задать параметры его работы.
		|Сделать это можно при помощи формы
		|""Настройка параметров"" модели подключаемого оборудования в форме ""Подключение и настройка оборудования"".'"));

		Result = False;
	EndIf; // End: Checks device parameters.

	If Result Then	
		Try
			DriverObject.AddLD();
    		ConnectionParameters.DeviceID	= DriverObject.LDNumber;
    		DriverObject.LDInterface 			= Interface;
    		DriverObject.Password				= Password;

    		If Interface = 0 Then
    			DriverObject.LDCOMPort       	 = Port;
    			DriverObject.LDExchangeSpeed	 = Speed;
    			DriverObject.LDTimeout       	 = Timeout;
    		Else
    			DriverObject.RecipientAddressLOU = IPAddress;
    			DriverObject.LDReceiverPort  = UDPReceiverPort;
    			DriverObject.UDPLDTimeout      = UDPTimeout;
    		EndIf;
			DriverObject.SetLDParameter();
		                     
		Except
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);
    		Result = False;	
		EndTry;
	EndIf;
 	
	Return Result;
	
EndFunction

// Function disconnects a device.
//
Function DisableDevice(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	// Required output
	Output_Parameters = New Array();
	Result = True;

	Try
		DriverObject.LDNumber = ConnectionParameters.DeviceID;
		DriverObject.SetActiveLD();
		DriverObject.Disconnect();
		DriverObject.IndexLE = 0;
		
		DriverObject.EnumerateLD();
		DriverObject.SetActiveLD();
		DriverObject.LDNumber = ConnectionParameters.DeviceID;
		DriverObject.DeleteLD();  
	Except
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Device disabling error';ru='Ошибка отключения устройства'"));
    	Result = False;	
	EndTry;
	
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
		Products 				= InputParameters[0];
		PartialExport 	= InputParameters[1];
		Result = ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters);
											  
	// Clear the base of scales with printing labels.
	ElsIf Command = "ClearBase" Then
		Result = ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Test device
	ElsIf Command = "DeviceTest" OR Command = "CheckHealth" Then
		Result = DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters);

	// Receive driver version
	ElsIf Command = "GetDriverVersion" Then
		Result = GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		
	// This command is not supported by the current driver.
	Else
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='The %Command% command is not supported by the current driver.';ru='Команда ""%Команда%"" не поддерживается данным драйвером.'"));
		Output_Parameters[1] = StrReplace(Output_Parameters[1], "%Command%", Command);

		Result = False;
	EndIf;

	Return Result;

EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

// Function exports the products table to the scales with labels printing.
//
Function ExportProducts(DriverObject, Parameters, ConnectionParameters, Products, PartialExport, Output_Parameters) Export
	
	Result = True;
	
	If Products.Count() = 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='There is no data to export.';ru='Нет данных для выгрузки.'"));
		Return False;
	EndIf;
		
	CurrentPercent = 0;
	Status(NStr("en='Initializing export...';ru='Инициализация выгрузки...'"), Round(CurrentPercent));
	
	DriverObject.LDNumber = ConnectionParameters.DeviceID;
	DriverObject.SetActiveLD();

	If DriverObject.Connect() <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);
		Return False;
	EndIf;
		
	If Result Then
		If Not PartialExport Then
			Result = BeginUnloading(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
		EndIf;	
    EndIf;	

	// Initialization import mode.
	If Result Then
		If Not PartialExport Then
			
			DriverObject.QuickImport = 0;
			DriverObject.SetImportingMode();
			
			If DriverObject.ClearProductsAndMessagesBase() <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(NStr("en='Failed to clear the items data base.';ru='Не удалось очистить базу товаров.'") + DriverObject.ResultDescription);
				Result = False;	
			EndIf;
		EndIf;

		If Result Then
			DriverObject.QuickImport = Parameters.QuickImport;
			If DriverObject.SetImportingMode() <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;	
			EndIf;
		EndIf;
	EndIf;

	If Result Then	             
		
		If Result  Then
			
			PercentIncrement = 100 / Products.Count();
			
			// Data export to scales with labels printing.
			For Each CurrentItem IN Products Do
				
				ProductDescription = CurrentItem.Description;
				
				If CurrentItem.Property("DescriptionFull") AND 
				  Not IsBlankString(CurrentItem.DescriptionFull) Then
					ProductDescription = CurrentItem.DescriptionFull;
				EndIf;
				
				If IsBlankString(CurrentItem.Code) Or (CurrentItem.Code = 0) Then
					ProductCodeTemp = Mid(CurrentItem.Barcode, 3, 6)
				Else
    				ProductCodeTemp = CurrentItem.Code;
    			EndIf;
	
				If CurrentItem.Property("StoragePeriod") Then	
					StoragePeriodTemp = CurrentItem.StoragePeriod;
				Else
					StoragePeriodTemp = 0;
				EndIf;
 			
				Result = Exporting(DriverObject, Output_Parameters, CurrentItem.PLU, ProductCodeTemp,
					ProductDescription, CurrentItem.Price, StoragePeriodTemp);
				If Not Result Then
					FinishExport(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
					Break;
				EndIf;
				
				CurrentPercent = CurrentPercent + PercentIncrement;
				Status(NStr("en='Exporting products...';ru='Выгрузка товаров...'"), Round(CurrentPercent));
				
			EndDo;
			
			If Result  Then
				Result = FinishExport(DriverObject, Parameters, ConnectionParameters, Output_Parameters);
			EndIf;
			
		EndIf; 
	EndIf; 
		                
	Return Result;

EndFunction

// Function exports an item to scales with labels printing.
//
Function Exporting(DriverObject, Output_Parameters, PLU, ProductCode, Description, Price, StoragePeriod)
	
	Result = True;
	TempName = TrimAll(Description);
	DriverObject.PLUNumber = PLU;
	DriverObject.FirstProductDescription = ?(StrLen(TempName) > 28, Left(TempName, 28), TempName);
	DriverObject.SecondProductDescription = ?(StrLen(TempName) > 28, Mid(TempName, 29), "");
	DriverObject.Tara                     = 0;
	If StoragePeriod > 0 Then
		DriverObject.StoragePeriod   = StoragePeriod;     
		DriverObject.DateOfSale = Date(2001, 1, 1);
	Else
		DriverObject.StoragePeriod   = 0;     
		DriverObject.DateOfSale = 0;
	EndIf;
	DriverObject.Price             = Number(Price);
	DriverObject.GroupCode     = 0;
	DriverObject.ProductCode        = Number(ProductCode);
	DriverObject.ImageNumber = 0;
	DriverObject.ROSTESTCode       = " ";
	DriverObject.ProductType        = 0;
	
	If Number(DriverObject.KEVersion) >= 3.0 Then
		
		DriverObject.AppendDataToPLDData();
		
		If DriverObject.Result = -21 Then // Block is full - send it, and we will write the goods into the cleared block later.
			If DriverObject.WritePLUDataBlock() <> 0 Then 
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;
			EndIf;
			DriverObject.ClearDataBlock();
			DriverObject.AppendDataToPLDData();
		EndIf
		
	Else
		If DriverObject.WritePLUData() <> 0 Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);
			Result = False;	
		EndIf;
	EndIf;
		
	If Not Result  Then
		DriverObject.QuickImport = 0;
		DriverObject.SetImportingMode();
	EndIf;
	
	Return Result;
	
EndFunction

Function BeginUnloading(DriverObject, Parameters, ConnectionParameters, Output_Parameters)
	
	Result = True;

	BarcodePrefixWeightProduct   = "2" + EquipmentManagerServerCallOverridable.GetWeightProductPrefix(Parameters.ID);
    PrefixForPiecePackagedProduct = "2" + EquipmentManagerServerCallOverridable.GetPieceProductPrefix(Parameters.ID);

	// Prefixes initialization
	DriverObject.FinalPrefixBC = 0;
	DriverObject.BCPrefixType = 2;

	If DriverObject.SetFinalPrefixBC() <> 0
	   AND DriverObject.SetBCPrefixType() <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);
		Result = False;	
	Else
		DriverObject.GetBCPrefix();
			
		If DriverObject.BCPiecePrefix = Number(BarcodePrefixWeightProduct)
		   AND DriverObject.BCWeightPrefix = Number(PrefixForPiecePackagedProduct) Then
			For ArbitraryPrefix = 20 To 29 Do
					
				If ArbitraryPrefix <> Number(BarcodePrefixWeightProduct)
				   AND ArbitraryPrefix <> Number(PrefixForPiecePackagedProduct) Then
					DriverObject.BCWeightPrefix = ArbitraryPrefix;
					DriverObject.SetBCWeightPrefix();
					Break;
				EndIf;
				
			EndDo;
			
			DriverObject.BCPiecePrefix = Number(PrefixForPiecePackagedProduct);
			DriverObject.SetBCPiecePrefix();
			DriverObject.BCWeightPrefix = Number(BarcodePrefixWeightProduct);
			DriverObject.SetBCWeightPrefix();
				
			If DriverObject.Result <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;	
			EndIf;
				                 
		ElsIf DriverObject.BCPiecePrefix = Number(BarcodePrefixWeightProduct) Then
			DriverObject.BCPiecePrefix = Number(PrefixForPiecePackagedProduct);
			DriverObject.SetBCPiecePrefix();
			
			DriverObject.BCWeightPrefix = Number(BarcodePrefixWeightProduct);
			DriverObject.SetBCWeightPrefix();

			If DriverObject.Result <> 0 Then
				Output_Parameters.Clear();
				Output_Parameters.Add(999);
				Output_Parameters.Add(DriverObject.ResultDescription);
				Result = False;	
			EndIf;
		Else
			
			If Number(BarcodePrefixWeightProduct) > 9 Then	
				DriverObject.BCWeightPrefix = Number(BarcodePrefixWeightProduct);
				DriverObject.SetBCWeightPrefix();
			If DriverObject.Result <> 0 Then
					Output_Parameters.Clear();
					Output_Parameters.Add(999);
					Output_Parameters.Add(DriverObject.ResultDescription);
					Result = False;	
				EndIf;
			EndIf;
			
			
			If Number(PrefixForPiecePackagedProduct) > 9 Then	
				DriverObject.BCPiecePrefix = Number(PrefixForPiecePackagedProduct);
				DriverObject.SetBCPiecePrefix();
				If DriverObject.Result <> 0 Then
					Output_Parameters.Clear();
					Output_Parameters.Add(999);
					Output_Parameters.Add(DriverObject.ResultDescription);
					Result = False;	
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// End of procedure of data export to scales with labels printing.
Function FinishExport(DriverObject, Parameters, ConnectionParameters, Output_Parameters) 
	
	Result = True;
	
	If Number(DriverObject.KEVersion) >= 3.0 Then
		If DriverObject.WritePLUDataBlock() <> 0 Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);
			Result = False;	
		EndIf;
		DriverObject.ClearDataBlock(); 
	EndIf;
	
	DriverObject.QuickImport = 0;
	If DriverObject.SetImportingMode() <> 0 Then
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);
		Result = False;	
	EndIf;

	Return Result;

EndFunction

// The function clears the products table to the scales with labels printing.
//
Function ClearProductsInScales(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export

	// Required output
	Output_Parameters = New Array();
	Result = True;
	
	Status(NStr("en='The products are being cleared in the scales with labels printing...';ru='Выполняется очистка товаров в весах с печатью этикеток...'"));
	
	DriverObject.LDNumber = ConnectionParameters.DeviceID;
	DriverObject.SetActiveLD();

	If DriverObject.Connect() <> 0 Then	
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(DriverObject.ResultDescription);
		Result = False;
	Else
		If DriverObject.ClearProductsAndMessagesBase() <> 0 Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);
			Result = False;
		EndIf;
	EndIf;

	Return Result;

EndFunction

// Function checks the paths where exchange files are stored.
//
Function DeviceTest(DriverObject, Parameters, ConnectionParameters, Output_Parameters) Export
	
	Result = True;
	
	Try
		DriverObject.AddLD();
   		DriverObject.LDInterface 			= Parameters.Interface;
   		DriverObject.Password				= Parameters.Password;
		
		If Parameters.Interface = 0 Then
    		DriverObject.LDCOMPort       	 = Parameters.Port;
    		DriverObject.LDExchangeSpeed	 = Parameters.Speed;
    		DriverObject.LDTimeout       	 = Parameters.Timeout;
    	Else
    		DriverObject.RecipientAddressLOU = Parameters.IPAddress;
    		DriverObject.LDReceiverPort  = Parameters.UDPReceiverPort;
    		DriverObject.UDPLDTimeout      = Parameters.UDPTimeout;
    	EndIf;
				
		DriverObject.SetLDParameter();
   		DriverObject.SetActiveLD();

				
		If DriverObject.Connect() <> 0 Then
			Output_Parameters.Clear();
			Output_Parameters.Add(999);
			Output_Parameters.Add(DriverObject.ResultDescription);
	   		Result = False;	
		EndIf;
	Except
		Output_Parameters.Clear();
		Output_Parameters.Add(999);
		Output_Parameters.Add(NStr("en='Not recognized error.';ru='Не опознанная ошибка.'"));
   		Result = False;	
	EndTry;
				
	Return Result;
	
EndFunction

// Function returns installed driver version.
//
Function GetDriverVersion(DriverObject, Parameters, ConnectionParameters, Output_Parameters)

	Result = True;

	Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
	Output_Parameters.Add(NStr("en='Not defined';ru='Не определена'"));

	Try
		Output_Parameters[1] = StrReplace(ProcessDriverVersion(DriverObject.STFileVersion), "1.", "A ")  + "."
				              + ProcessDriverVersion(DriverObject.FileVersionML);
    Except
	EndTry;

	Return Result;

EndFunction

// Data processor of driver version
Function ProcessDriverVersion(VersionOfDriver)
	
	// Convert to binary value.
	BinaryValue = "";
	ValueRemain = VersionOfDriver;
	While ValueRemain > 0 Do
		DivisionResult = ValueRemain / 2;
		BinaryValue = ?(DivisionResult = Int(DivisionResult), "0", "1") + BinaryValue;
		ValueRemain  = Int(DivisionResult);
	EndDo;

	// Select the major and minor parts.
	MajorPart = ?(StrLen(BinaryValue) > 16, Mid(BinaryValue, 1, StrLen(BinaryValue) - 16), "0");
	MinorPart = ?(StrLen(BinaryValue) > 16, Right(BinaryValue, 16), BinaryValue);

	DecimalValue = 0;
	For CurrentChar = 1 To StrLen(MajorPart) Do
		DecimalValue = DecimalValue * 2 + Number(Mid(MajorPart, CurrentChar, 1));
	EndDo;
	DriverVersion = String(DecimalValue) + ".";

	DecimalValue = 0;
	For CurrentChar = 1 To StrLen(MinorPart) Do
		DecimalValue = DecimalValue * 2 + Number(Mid(MinorPart, CurrentChar, 1));
	EndDo;
	DriverVersion = DriverVersion + String(DecimalValue);

	Return DriverVersion;

EndFunction

#EndRegion