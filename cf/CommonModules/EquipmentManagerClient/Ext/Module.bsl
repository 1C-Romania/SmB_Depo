
#Region ProceduresAndFunctionsEnableDisableEquipmentSynchronously

// Connects available peripherals from a list of available peripherals
//
Function ConnectEquipmentByType(ClientID, EETypes, ErrorDescription = "") Export
	
	StructureSWTypes = New Structure();
	If TypeOf(EETypes) = Type("Array") Then
		For Each EEType IN EETypes Do
			StructureSWTypes.Insert(EEType);
		EndDo;
	Else
		StructureSWTypes.Insert(EETypes);
	EndIf;
	
	Return ConnectEquipment(ClientID, StructureSWTypes, , ErrorDescription);
	 
 EndFunction

// Enables device single copy defined by identifier.
//
Function ConnectEquipmentByID(ClientID, DeviceIdentifier, ErrorDescription = "") Export
	
	Return ConnectEquipment(ClientID, , DeviceIdentifier, ErrorDescription);
	
EndFunction

// Function enables devices by the equipment type.
// Returns the result of function execution.
Function ConnectEquipment(ClientID, EETypes = Undefined,
							   DeviceIdentifier = Undefined, ErrorDescription = "") Export
	   
	FinalResult = True;
	Result         = True;
	
	DriverObject    = Undefined;
	ErrorDescription    = "";
	DeviceErrorDescription = "";

	Result = EquipmentManagerClient.RefreshClientWorkplace();
	If Not Result Then
		ErrorDescription = NStr("en='It is required to select a work place of the current peripheral session in advance.';ru='Предварительно необходимо выбрать рабочее место подключаемого оборудования текущего сеанса.'");
		Return False;
	EndIf;
	
	EquipmentList = EquipmentManagerClientReUse.GetEquipmentList(EETypes, DeviceIdentifier);
	
	If EquipmentList.Count() > 0 Then
		For Each Device IN EquipmentList Do
			
			// Check if the device is enabled earlier.
			ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, Device.Ref);
			
			If ConnectedDevice = Undefined Then // If device is not enabled earlier.
				DriverObject = GetDriverObject(Device);
				If DriverObject = Undefined Then
					// Error message prompting that the driver can not be imported.
					ErrorDescription = ErrorDescription + ?(IsBlankString(ErrorDescription), "", Chars.LF)
								   + NStr("en='%Description%: Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Description%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
					ErrorDescription = StrReplace(ErrorDescription, "%Description%", Device.Description);
					FinalResult = False;
					Continue;
				EndIf;
				
				ANewConnection = New Structure();
				ANewConnection.Insert("Clients"               , New Array());
				ANewConnection.Clients.Add(ClientID);
				ANewConnection.Insert("Ref"                 , Device.Ref);
				ANewConnection.Insert("DeviceIdentifier", Device.DeviceIdentifier);
				ANewConnection.Insert("DriverHandler"     , Device.DriverHandler);
				ANewConnection.Insert("Description"           , Device.Description);
				ANewConnection.Insert("EquipmentType"        , Device.EquipmentType);
				ANewConnection.Insert("HardwareDriver"    , Device.HardwareDriver);
				ANewConnection.Insert("AsConfigurationPart"   , Device.AsConfigurationPart);
				ANewConnection.Insert("ObjectID"   , Device.ObjectID);
				ANewConnection.Insert("DriverTemplateName"      , Device.DriverTemplateName);
				ANewConnection.Insert("DriverFileName"       , Device.DriverFileName);
				ANewConnection.Insert("Workplace"           , Device.Workplace);
				ANewConnection.Insert("ComputerName"          , Device.ComputerName);
				ANewConnection.Insert("Parameters"              , Device.Parameters);
				ANewConnection.Insert("CountOfConnected" , 1);
				ANewConnection.Insert("ConnectionParameters"   , New Structure());
				ANewConnection.ConnectionParameters.Insert("EquipmentType", Device.EquipmentTypeName);
				
				Output_Parameters = Undefined;
				
				DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ANewConnection.DriverHandler, Not ANewConnection.AsConfigurationPart);
				If DriverHandler = Undefined Then
					// Error message prompting that the driver can not be imported.
					ErrorDescription = ErrorDescription +  NStr("en='Failed to connect the driver handler.';ru='Не удалось подключить обработчик драйвера.'");
					FinalResult = False;
					Continue;
				Else
					// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
					If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
						DriverHandler = PeripheralsUniversalDriverClient;
					EndIf;
					
					Result = DriverHandler.ConnectDevice(
						DriverObject,
						ANewConnection.Parameters,
						ANewConnection.ConnectionParameters,
						Output_Parameters);
				EndIf;
				
				If Result Then
					If Output_Parameters.Count() >= 2 Then
						ANewConnection.Insert("EventSource", Output_Parameters[0]);
						ANewConnection.Insert("NamesEvents",    Output_Parameters[1]);
					Else
						ANewConnection.Insert("EventSource", "");
						ANewConnection.Insert("NamesEvents",    Undefined);
					EndIf;
					glPeripherals.PeripheralsConnectingParameters.Add(ANewConnection);
				Else
					// Inform user that a peripheral failed to be connected.
					ErrorDescription = ErrorDescription + ?(IsBlankString(ErrorDescription), "", Chars.LF)
								   + NStr("en='Cannot connect peripheral ""%Description%"": %ErrorDescription% (%ErrorCode%)';ru='Не удалось подключить устройство ""%Наименование%"": %ОписаниеОшибки% (%КодОшибки%)'");
					ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , Device.Description);
					ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
					ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Output_Parameters[0]);
				EndIf;
			Else // Device was enabled earlier.
				// Increase quantity of this connection users.
				ConnectedDevice.Clients.Add(ClientID);
				ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected + 1;
			EndIf;
			
			FinalResult = FinalResult AND Result;
		EndDo;
	ElsIf DeviceIdentifier <> Undefined Then
		ErrorDescription = NStr("en='The selected peripheral can not be used for connection.
		|Specify other device.';ru='Выбранное устройство не может использоваться для подключения.
		|Укажите другое устройство.'");
		FinalResult = False;
	EndIf;

	Return FinalResult;

EndFunction

// Search by identifier of the previously connected peripheral.
//
Function GetConnectedDevice(ConnectionsList, ID) Export
	
	ConnectedDevice = Undefined;
	
	For Each Connection IN ConnectionsList Do
		If Connection.Ref = ID Then
			ConnectedDevice = Connection;
			Break;
		EndIf;
	EndDo;
	
	Return ConnectedDevice;
	
EndFunction

// Disables devices by the equipment type.
//
Function DisableEquipmentByType(ClientID, EETypes, ErrorDescription = "") Export

	Return DisableEquipment(ClientID, EETypes, ,ErrorDescription);

EndFunction

// Disables device defined by identifier.
//
Function DisableEquipmentById(ClientID, DeviceIdentifier, ErrorDescription = "") Export

	Return DisableEquipment(ClientID, , DeviceIdentifier, ErrorDescription);

EndFunction

// Forcefully disables all peripherals
// regardless of refs to connection quantity.
Function DisableAllEquipment(ErrorDescription = "") Export
	
	FinalResult = True;
	Result         = True;
	
	For Each ConnectedDevice IN glPeripherals.PeripheralsConnectingParameters Do
		
		DriverObject = GetDriverObject(ConnectedDevice);
		If DriverObject = Undefined Then
			// Error message prompting that the driver can not be imported.
			ErrorDescription = NStr("en='""%Description%"": Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Наименование%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
			FinalResult = False;
			Continue;
		EndIf;
		
		Output_Parameters = Undefined;
		
		DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
		
		// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
		If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
			DriverHandler = PeripheralsUniversalDriverClient;
		EndIf;
	
		Result = DriverHandler.DisableDevice(
				DriverObject,
				ConnectedDevice.Parameters,
				ConnectedDevice.ConnectionParameters,
				Output_Parameters);
				
		If Not Result Then
			ErrorDescription = NStr("en='An error occurred while disconnecting peripheral ""%Description%"": %ErrorDescription% (%ErrorCode%)';ru='При отключении устройства ""%Наименование%"" произошла ошибка: %ОписаниеОшибки% (%КодОшибки%)'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%", Output_Parameters[0]);
		Else
			ConnectedDevice.CountOfConnected = 0;
		EndIf;
		FinalResult = FinalResult AND Result;
	EndDo;
	
	glPeripherals.PeripheralsConnectingParameters.Clear();
	
	Return FinalResult;
	
EndFunction

// Function enables devices by the equipment type.
// 
Function DisableEquipment(ClientID, EETypes = Undefined, DeviceIdentifier = Undefined, ErrorDescription = "")
	
	FinalResult = True;
	Result         = True;
	
	OutputErrorDescription = "";
	
	If glPeripherals.PeripheralsConnectingParameters <> Undefined Then
		CountDevices = glPeripherals.PeripheralsConnectingParameters.Count();
		For IndexOf = 1 To CountDevices Do
			
			ConnectedDevice = glPeripherals.PeripheralsConnectingParameters[CountDevices - IndexOf];
			TypeNameOfSoftware = EquipmentManagerClientReUse.GetEquipmentTypeName(ConnectedDevice.EquipmentType);
			ClientConnection = ConnectedDevice.Clients.Find(ClientID);
			If ClientConnection <> Undefined  AND (EETypes = Undefined Or EETypes.Find(TypeNameOfSoftware) <> Undefined)
			   AND (DeviceIdentifier = Undefined  Or ConnectedDevice.Ref = DeviceIdentifier)Then
				 
				 If ConnectedDevice.CountOfConnected = 1 Then
					 
					DriverObject = GetDriverObject(ConnectedDevice);
					If DriverObject = Undefined Then
						// Error message prompting that the driver can not be imported.
						ErrorDescription = NStr("en='""%Description%"": Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Наименование%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
						ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
						FinalResult = False;
						Continue;
					EndIf;
					
					Output_Parameters = Undefined;
					
					DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
					
					// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
					If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
						DriverHandler = PeripheralsUniversalDriverClient;
					EndIf;
					
					Result = DriverHandler.DisableDevice(
							DriverObject,
							ConnectedDevice.Parameters,
							ConnectedDevice.ConnectionParameters,
							Output_Parameters);
							
					If Not Result Then
						ErrorDescription = ErrorDescription + ?(IsBlankString(ErrorDescription), "", Chars.LF)
									   + NStr("en='An error occurred while disconnecting peripheral ""%Description%"": %ErrorDescription% (%ErrorCode%)';ru='При отключении устройства ""%Наименование%"" произошла ошибка: %ОписаниеОшибки% (%КодОшибки%)'");
						ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
						ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
						ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%", Output_Parameters[0]);
					Else
						ConnectedDevice.CountOfConnected = 0;
					EndIf;
					
					ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(ConnectedDevice);
					If ArrayLineNumber <> Undefined Then
						glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
					EndIf;
				Else
					ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected - 1;
					ConnectedDevice.Clients.Delete(ClientConnection);
				EndIf;
			EndIf;
			
			FinalResult = FinalResult AND Result;
		EndDo;
	EndIf;
	
	Return FinalResult;
	
EndFunction  

#EndRegion   

#Region ProceduresAndFunctionsEquipmentConnectionAsynchronously

// Connects available peripherals from a list of available peripherals
//
Procedure StartEnableEquipmentByType(AlertOnConnect, ClientID, EETypes) Export
	
	StructureSWTypes = New Structure();
	If TypeOf(EETypes) = Type("Array") Then
		For Each EEType IN EETypes Do
			StructureSWTypes.Insert(EEType);
		EndDo;
	Else
		StructureSWTypes.Insert(EETypes);
	EndIf;
	
	StartConnectPeripheral(AlertOnConnect, ClientID, StructureSWTypes);
	 
 EndProcedure

// Start enabling device single copy defined by identifier.
//
Procedure StartEquipmentEnablingByIdidentifier(AlertOnConnect, ClientID, DeviceIdentifier) Export
	
	StartConnectPeripheral(AlertOnConnect, ClientID, , DeviceIdentifier);
	
EndProcedure

Procedure StartEnableEquipmentEnd(ExecutionResult, Parameters) Export
	
	If ExecutionResult.Result Then
		If ExecutionResult.Output_Parameters.Count() >= 2 Then
			Parameters.ANewConnection.Insert("EventSource", Parameters.Output_Parameters[0]);
			Parameters.ANewConnection.Insert("NamesEvents",    Parameters.Output_Parameters[1]);
		Else
			Parameters.ANewConnection.Insert("EventSource", "");
			Parameters.ANewConnection.Insert("NamesEvents",    Undefined);
		EndIf;
		glPeripherals.PeripheralsConnectingParameters.Add(Parameters.ANewConnection);
		If Parameters.AlertOnConnect <> Undefined Then
			ErrorDescription = NStr("en='No errors.';ru='Ошибок нет.'");
			ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnConnect, ExecutionResult);
		EndIf;
	Else
		// Inform user that a peripheral failed to be connected.
		If Parameters.AlertOnConnect <> Undefined Then
			ErrorDescription = NStr("en='Cannot connect peripheral ""%Description%"": %ErrorDescription% (%ErrorCode%)';ru='Не удалось подключить устройство ""%Наименование%"": %ОписаниеОшибки% (%КодОшибки%)'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , Parameters.ANewConnection.Description);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Parameters.Output_Parameters[1]);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Parameters.Output_Parameters[0]);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnConnect, ExecutionResult);
		EndIf;
	EndIf;
	
EndProcedure

Procedure StartEnablingDeviceGettingDriverObjectEnd(DriverObject, Parameters) Export
	
	If DriverObject = Undefined Then
		
		If Parameters.AlertOnConnect <> Undefined Then
			// Error message prompting that the driver can not be imported.
			ErrorDescription = NStr("en='%Description%: Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Description%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", Parameters.ANewConnection.Description);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnConnect, ExecutionResult);
		EndIf;
		
	Else
		Notification = New NotifyDescription("StartEnableEquipmentEnd", ThisObject, Parameters);
		Parameters.DriverHandler.StartEnableDevice(Notification, DriverObject, 
			 Parameters.ANewConnection.Parameters,  Parameters.ANewConnection.ConnectionParameters, Parameters);
	EndIf;
	
EndProcedure

// Start connecting a peripheral.
// 
Procedure StartConnectPeripheral(AlertOnConnect, ClientID, EETypes = Undefined, DeviceIdentifier = Undefined) Export
	   
	DriverObject = Undefined;
	
	Result = EquipmentManagerClient.RefreshClientWorkplace();
	If Not Result Then
		If AlertOnConnect <> Undefined Then
			ErrorDescription = NStr("en='It is required to select a work place of the current peripheral session in advance.';ru='Предварительно необходимо выбрать рабочее место подключаемого оборудования текущего сеанса.'");
			ExecutionResult = New Structure("Result, ErrorDetails", Result, ErrorDescription);
			ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
		EndIf;
	EndIf;
	
	EquipmentList = EquipmentManagerClientReUse.GetEquipmentList(EETypes, DeviceIdentifier);
	
	If EquipmentList.Count() > 0 Then
		For Each Device IN EquipmentList Do
			
			// Check if the device is enabled earlier.
			ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, Device.Ref);
			
			If ConnectedDevice = Undefined Then // If device is not enabled earlier.
				
				DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(Device.DriverHandler, Not Device.AsConfigurationPart);
				
				ANewConnection = New Structure();
				ANewConnection.Insert("Clients"               , New Array());
				ANewConnection.Clients.Add(ClientID);
				ANewConnection.Insert("Ref"                 , Device.Ref);
				ANewConnection.Insert("DeviceIdentifier", Device.DeviceIdentifier);
				ANewConnection.Insert("DriverHandler"     , Device.DriverHandler);
				ANewConnection.Insert("Description"           , Device.Description);
				ANewConnection.Insert("EquipmentType"        , Device.EquipmentType);
				ANewConnection.Insert("HardwareDriver"    , Device.HardwareDriver);
				ANewConnection.Insert("AsConfigurationPart"   , Device.AsConfigurationPart);
				ANewConnection.Insert("ObjectID"   , Device.ObjectID);
				ANewConnection.Insert("DriverTemplateName"      , Device.DriverTemplateName);
				ANewConnection.Insert("DriverFileName"       , Device.DriverFileName);
				ANewConnection.Insert("Workplace"           , Device.Workplace);
				ANewConnection.Insert("ComputerName"          , Device.ComputerName);
				ANewConnection.Insert("Parameters"              , Device.Parameters);
				ANewConnection.Insert("CountOfConnected" , 1);
				ANewConnection.Insert("ConnectionParameters"   , New Structure());
				ANewConnection.ConnectionParameters.Insert("EquipmentType", Device.EquipmentTypeName);
				
				If DriverHandler = Undefined Then
					// Report an error: can not connect the handler.
					If AlertOnConnect <> Undefined Then
						ErrorDescription = NStr("en='Failed to connect the driver handler.';ru='Не удалось подключить обработчик драйвера.'");
						ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
						ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
					EndIf;
					Continue;
				Else
					
					// Split on asynchronous and synchronous calls.
					If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
						// Asynchronous calls
						CommandParameters = New Structure("NewConnection, AlertOnEnabling, DriverHandler", ANewConnection, AlertOnConnect, DriverHandler);
						Notification = New NotifyDescription("StartEnablingDeviceGettingDriverObjectEnd", ThisObject, CommandParameters);
						StartReceivingDriverObject(Notification, Device);
					Else
						// Simultaneous
						DriverObject = GetDriverObject(Device);
						If DriverObject = Undefined Then
							If AlertOnConnect <> Undefined Then
								// Error message prompting that the driver can not be imported.
								ErrorDescription = NStr("en='%Description%: Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Description%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
								ErrorDescription = StrReplace(ErrorDescription, "%Description%",ANewConnection.Description);
								ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
								ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
							EndIf;
							Continue;
						Else
							Output_Parameters = Undefined;
							Result = DriverHandler.ConnectDevice(DriverObject, ANewConnection.Parameters, ANewConnection.ConnectionParameters, Output_Parameters);
							
							If Result Then
								
								If Output_Parameters.Count() >= 2 Then
									ANewConnection.Insert("EventSource", Output_Parameters[0]);
									ANewConnection.Insert("NamesEvents",    Output_Parameters[1]);
								Else
									ANewConnection.Insert("EventSource", "");
									ANewConnection.Insert("NamesEvents",    Undefined);
								EndIf;
								glPeripherals.PeripheralsConnectingParameters.Add(ANewConnection);
								
								If AlertOnConnect <> Undefined Then
									ErrorDescription = NStr("en='No errors.';ru='Ошибок нет.'");
									ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
								EndIf;
								
							Else
								// Inform user that a peripheral failed to be connected.
								If AlertOnConnect <> Undefined Then
									ErrorDescription = NStr("en='Cannot connect peripheral ""%Description%"": %ErrorDescription% (%ErrorCode%)';ru='Не удалось подключить устройство ""%Наименование%"": %ОписаниеОшибки% (%КодОшибки%)'");
									ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , ANewConnection.Description);
									ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
									ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Output_Parameters[0]);
									ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
								EndIf;
							EndIf;
						EndIf;
						
					EndIf;
					
				EndIf;
			
			Else // Device was enabled earlier.
				// Increase quantity of this connection users.
				ConnectedDevice.Clients.Add(ClientID);
				ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected + 1;
			EndIf;
			
		EndDo;
		
	ElsIf  DeviceIdentifier <> Undefined AND AlertOnConnect <> Undefined Then
		ErrorDescription =  NStr("en='The selected peripheral can not be used for connection. Specify other device.';ru='Выбранное устройство не может использоваться для подключения. Укажите другое устройство.'");
		ExecutionResult = New Structure("Result, ErrorDetails", Result, ErrorDescription);
		ExecuteNotifyProcessing(AlertOnConnect, ExecutionResult);
	EndIf;
	
EndProcedure

// Start disabling devices by equipment type.
//
Procedure StartDisconnectEquipmentByType(AlertOnDisconnect, ClientID, EETypes) Export
	
	StartDisconnectEquipment(AlertOnDisconnect, ClientID, EETypes, );
	
EndProcedure

//  Start disconnecting a peripheral defined by an identifier.
//
Procedure StartDisableEquipmentByIdidentifier(AlertOnDisconnect, ClientID, DeviceIdentifier) Export
	
	StartDisconnectEquipment(AlertOnDisconnect, ClientID, , DeviceIdentifier);
	
EndProcedure

Procedure StartDisconnectEquipmentEnd(ExecutionResult, Parameters) Export
	
	If ExecutionResult.Result Then
		
		Parameters.ConnectedDevice.CountOfConnected = 0;
		
		ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(Parameters.ConnectedDevice);
		If ArrayLineNumber <> Undefined Then
			glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
		EndIf;
		If Parameters.AlertOnDisconnect <> Undefined Then
			ErrorDescription = NStr("en='No errors.';ru='Ошибок нет.'");
			ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnDisconnect, ExecutionResult);
		EndIf;
	Else
		// Inform user that a peripheral failed to be connected.
		If Parameters.AlertOnDisconnect <> Undefined Then
			ErrorDescription = NStr("en='An error occurred while disconnecting peripheral ""%Description%"": %ErrorDescription% (%ErrorCode%)';ru='При отключении устройства ""%Наименование%"" произошла ошибка: %ОписаниеОшибки% (%КодОшибки%)'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , Parameters.ConnectedDevice.Description);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Parameters.Output_Parameters[1]);
			ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Parameters.Output_Parameters[0]);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnDisconnect, ExecutionResult);
		EndIf;
	EndIf;

EndProcedure

Procedure StartDisconnectEquipmentGettingDriverObjectEnd(DriverObject, Parameters) Export
	
	If DriverObject = Undefined Then
		
		If Parameters.AlertOnDisconnect <> Undefined Then
			// Error message prompting that the driver can not be imported.
			ErrorDescription = NStr("en='%Description%: Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Description%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", Parameters.ConnectedDevice.Description);
			ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
			ExecuteNotifyProcessing(Parameters.AlertOnDisconnect, ExecutionResult);
		EndIf;
		
	Else
		Notification = New NotifyDescription("StartDisconnectEquipmentEnd", ThisObject, Parameters);
		Parameters.DriverHandler.StartDisableDevice(Notification, DriverObject, 
			 Parameters.ConnectedDevice.Parameters,  Parameters.ConnectedDevice.ConnectionParameters, Undefined);
	EndIf;
	
EndProcedure

// Function enables devices by the equipment type.
// 
Procedure StartDisconnectEquipment(AlertOnDisconnect, ClientID, EETypes = Undefined, DeviceIdentifier = Undefined)
	
	If glPeripherals.PeripheralsConnectingParameters <> Undefined Then
		CountDevices = glPeripherals.PeripheralsConnectingParameters.Count();
		For IndexOf = 1 To CountDevices Do
			
			ConnectedDevice = glPeripherals.PeripheralsConnectingParameters[CountDevices - IndexOf];
			TypeNameOfSoftware = EquipmentManagerClientReUse.GetEquipmentTypeName(ConnectedDevice.EquipmentType);
			ClientConnection = ConnectedDevice.Clients.Find(ClientID);
			If ClientConnection <> Undefined  AND (EETypes = Undefined Or EETypes.Find(TypeNameOfSoftware) <> Undefined)
			   AND (DeviceIdentifier = Undefined  Or ConnectedDevice.Ref = DeviceIdentifier)Then
				
				If ConnectedDevice.CountOfConnected = 1 Then
					
					DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
					If DriverHandler = Undefined Then
						// Report an error: can not connect the handler.
						If AlertOnDisconnect <> Undefined Then
							ErrorDescription = NStr("en='Failed to connect the driver handler.';ru='Не удалось подключить обработчик драйвера.'");
							ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
							ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
						EndIf;
					Else
						// Split on asynchronous and synchronous calls.
						If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
							// Asynchronous calls
							CommandParameters = New Structure("ConnectedDevice, AlertOnDisconnect, DriverHandler", ConnectedDevice, AlertOnDisconnect, DriverHandler);
							Notification = New NotifyDescription("StartDisconnectEquipmentGettingDriverObjectEnd", ThisObject, CommandParameters);
							StartReceivingDriverObject(Notification, ConnectedDevice);
						Else
							DriverObject = GetDriverObject(ConnectedDevice);
							If DriverObject = Undefined Then
								If AlertOnDisconnect <> Undefined Then
									// Error message prompting that the driver can not be imported.
									ErrorDescription = NStr("en='%Description%: Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Description%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
									ErrorDescription = StrReplace(ErrorDescription, "%Description%",ConnectedDevice.Description);
									ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
								EndIf;
							Else
								Output_Parameters = Undefined;
								Result = DriverHandler.DisableDevice(DriverObject, ConnectedDevice.Parameters, ConnectedDevice.ConnectionParameters, Output_Parameters);
								If Not Result Then
									// Inform user that a peripheral failed to be connected.
									If AlertOnDisconnect <> Undefined Then
										ErrorDescription = NStr("en='An error occurred while disconnecting peripheral ""%Description%"": %ErrorDescription% (%ErrorCode%)';ru='При отключении устройства ""%Наименование%"" произошла ошибка: %ОписаниеОшибки% (%КодОшибки%)'");
										ErrorDescription = StrReplace(ErrorDescription, "%Description%"  , ConnectedDevice.Description);
										ErrorDescription = StrReplace(ErrorDescription, "%ErrorDescription%", Output_Parameters[1]);
										ErrorDescription = StrReplace(ErrorDescription, "%ErrorCode%"     , Output_Parameters[0]);
										ExecutionResult = New Structure("Result, ErrorDetails", False, ErrorDescription);
										ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
									EndIf;
								Else
									ConnectedDevice.CountOfConnected = 0;
								EndIf;
								
								ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(ConnectedDevice);
								If ArrayLineNumber <> Undefined Then
									glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
								EndIf;
								
								If AlertOnDisconnect <> Undefined Then
									ErrorDescription = NStr("en='No errors.';ru='Ошибок нет.'");
									ExecutionResult = New Structure("Result, ErrorDetails", True, ErrorDescription);
									ExecuteNotifyProcessing(AlertOnDisconnect, ExecutionResult);
								EndIf;
								
							EndIf;
							
						EndIf;
					EndIf;
					
				Else
					ConnectedDevice.CountOfConnected = ConnectedDevice.CountOfConnected - 1;
					ConnectedDevice.Clients.Delete(ClientConnection);
				EndIf;
			EndIf;
			
		EndDo;
	EndIf;
	
EndProcedure  

#EndRegion   

#Region ProceduresAndFunctionsEnableDisableEquipmentInForm

// Connects required peripheral types on opening the form.
//
// Parameters:
// Form - ManagedForm
// SupportedPeripheralTypes - String
// 	Contains peripherals types list separated by commas.
//
Function ConnectEquipmentOnOpenForms(Form, SupportedPeripheralTypes) Export
	
	EquipmentConnected = True;
	
	Form.SupportedPeripheralTypes = SupportedPeripheralTypes;
	
	If Form.UsePeripherals AND RefreshClientWorkplace() Then

		ErrorDescription = "";
		
		EquipmentConnected = ConnectEquipmentByType(
			Form.UUID,
			ConvertStringToArrayList(Form.SupportedPeripheralTypes),
			ErrorDescription);
		
		If Not EquipmentConnected Then
			
			MessageText = NStr("en='An error occurred while
		|connecting peripherals: ""%ErrorDetails%"".';ru='При подключении оборудования
		|произошла ошибка: ""%ОписаниеОшибки%"".'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
	Return EquipmentConnected; // Shows that an error occurs while enabling equipment.
	
EndFunction

// Disconnects required peripheral types on closing the form.
//
Function DisconnectEquipmentOnCloseForms(Form) Export
	
	Return EquipmentManagerClient.DisableEquipmentByType(
				Form.UUID,
				ConvertStringToArrayList(Form.SupportedPeripheralTypes));
	
EndFunction

// Start enabling required devices types during form opening
//
// Parameters:
// Form - ManagedForm
// SupportedPeripheralTypes - String
// 	Contains peripherals types list separated by commas.
//
Procedure StartConnectingEquipmentOnFormOpen(AlertOnConnect, Form, SupportedPeripheralTypes) Export
	
	Form.SupportedPeripheralTypes = SupportedPeripheralTypes;
	
	If Form.UsePeripherals AND RefreshClientWorkplace() Then
		StartEnableEquipmentByType(AlertOnConnect,
											Form.UUID,
											ConvertStringToArrayList(Form.SupportedPeripheralTypes));
	EndIf;
	
EndProcedure

// Start disconnecting peripherals by type on closing the form.
//
Procedure StartDisablingEquipmentOnCloseForm(AlertOnDisconnect, Form) Export
	
	StartDisconnectEquipmentByType(AlertOnDisconnect, 
										Form.UUID, 
										ConvertStringToArrayList(Form.SupportedPeripheralTypes));
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForWorkWithPeripherals

// Directs command to the
// responsible driver handler (according to the specified handler value in the "Identifier" incoming parameter).
Function RunCommand(ID, Command, InputParameters, Output_Parameters, Timeout = -1) Export
	
	Result = False;
	
	// Search for enabled device.
	ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, ID);
	
	If ConnectedDevice <> Undefined Then
		// Getting a driver object
		DriverObject = GetDriverObject(ConnectedDevice);
		If DriverObject = Undefined Then
			
			// Error message prompting that the driver can not be imported.
			Output_Parameters = New Array();
			ErrorDescription = NStr("en='""%Description%"": Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Description%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
			ErrorDescription = StrReplace(ErrorDescription, "%Description%", ConnectedDevice.Description);
			Output_Parameters.Add(999);
			Output_Parameters.Add(ErrorDescription);
			
		Else
			
			Parameters            = ConnectedDevice.Parameters;
			ConnectionParameters = ConnectedDevice.ConnectionParameters;
			
			DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(ConnectedDevice.DriverHandler, Not ConnectedDevice.AsConfigurationPart);
			
			If DriverHandler = Undefined Then
				// Error message prompting that the driver can not be imported.
				Output_Parameters = New Array();
				MessageText = NStr("en='Failed to connect the driver handler.';ru='Не удалось подключить обработчик драйвера.'");
				Output_Parameters.Add(999);
				Output_Parameters.Add(MessageText);
				Output_Parameters.Add(NStr("en='Not set';ru='Не установлен'"));
			Else
				// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
				If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
					DriverHandler = PeripheralsUniversalDriverClient;
				EndIf;
				// Call command execution method from handler.
				Result = DriverHandler.RunCommand(Command,
					InputParameters,
					Output_Parameters,
					DriverObject,
					Parameters,
					ConnectionParameters); 
			EndIf
			
		EndIf;
	Else
		// Report an error saying that the device is not connected.
		Output_Parameters = New Array();
		MessageText = NStr("en='The peripheral is not connected. Before the operation performance the device must be connected.';ru='Устройство не подключено. Перед выполнением операции устройство должно быть подключено.'");
		Output_Parameters.Add(999);
		Output_Parameters.Add(MessageText);
	EndIf;

	Return Result;

EndFunction

// Performs an additional command to the driver not requiring preliminary device connection in system.
//
Function RunAdditionalCommand(Command, InputParameters, Output_Parameters, ID, Parameters) Export
	
	Result = False;
	
	// Search for enabled device.
	ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, ID);

	If ConnectedDevice = Undefined Then
		
		EquipmentData = EquipmentManagerServerCall.GetDeviceData(ID);
		
		TempConnectionParameters = New Structure();
		TempConnectionParameters.Insert("EquipmentType", EquipmentData.EquipmentTypeName);
		
		DriverObject = GetDriverObject(EquipmentData);
		
		If DriverObject = Undefined Then
			
			// Error message prompting that the driver can not be imported.
			Output_Parameters = New Array();
			MessageText = NStr("en='Unable to import device driver.
		|Check if the driver is correctly installed and registered in the system.';ru='Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
			Output_Parameters.Add(999);
			Output_Parameters.Add(MessageText);
			Output_Parameters.Add(NStr("en='Not set';ru='Не установлен'"));
			
		Else
			
			DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(EquipmentData.DriverHandler, Not EquipmentData.AsConfigurationPart);
		
			If DriverHandler = Undefined Then
				// Error message prompting that the driver can not be imported.
				Output_Parameters = New Array();
				MessageText = NStr("en='Failed to connect the driver handler.';ru='Не удалось подключить обработчик драйвера.'");
				Output_Parameters.Add(999);
				Output_Parameters.Add(MessageText);
				Output_Parameters.Add(NStr("en='Not set';ru='Не установлен'"));
			Else
				// Forcefully replace asynchronous handler to the synchronous one as you work in the synchronous mode.
				If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
					DriverHandler = PeripheralsUniversalDriverClient;
				EndIf;
				Result = DriverHandler.RunCommand(Command,
					InputParameters,
					Output_Parameters,
					DriverObject,
					Parameters,
					TempConnectionParameters);
					If Not Result Then
						Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
					EndIf;
			EndIf
				
		EndIf;
	Else
		// Report an error saying that the device is enabled.
		Output_Parameters = New Array();
		MessageText = NStr("en='The equipment is connected. Before you start, the device must be disabled.';ru='Устройство подключено. Перед выполнением операции устройство должно быть отключено.'");
		Output_Parameters.Add(999);
		Output_Parameters.Add(MessageText);
		Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
	EndIf;
	
	Return Result;
	
EndFunction

// End execution of the additional driver command to driver not requiring
// preliminary device connection in system.
//
Procedure StartAdditionalCommandExecutionEnd(DriverObject, CommandParameters) Export
	
	If DriverObject = Undefined Then
		// Error message prompting that the driver can not be imported.
		ErrorText = NStr("en='Unable to import device driver.
		|Check if the driver is correctly installed and registered in the system.';ru='Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
		Output_Parameters = New Array();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorText);
		Output_Parameters.Add(NStr("en='Not set';ru='Не установлен'"));
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		ExecuteNotifyProcessing(CommandParameters.AlertOnEnd, ExecutionResult);
	Else
		
		DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(CommandParameters.EquipmentData.DriverHandler, Not CommandParameters.EquipmentData.AsConfigurationPart);
		
		If DriverHandler = Undefined Then
			// Inform that the driver handler failed to be connected.
			ErrorText = NStr("en='Failed to connect the driver handler.';ru='Не удалось подключить обработчик драйвера.'");
			Output_Parameters = New Array();
			Output_Parameters.Add(999);
			Output_Parameters.Add(ErrorText);
			Output_Parameters.Add(NStr("en='Not set';ru='Не установлен'"));
			ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
			ExecuteNotifyProcessing(CommandParameters.AlertOnEnd, ExecutionResult);
		Else
			TempConnectionParameters = New Structure();
			TempConnectionParameters.Insert("EquipmentType", CommandParameters.EquipmentData.EquipmentTypeName);
			
			If DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
				DriverHandler.StartCommandExecution(CommandParameters.AlertOnEnd, CommandParameters.Command, CommandParameters.InputParameters,
					DriverObject, CommandParameters.Parameters, TempConnectionParameters);
			Else
				Output_Parameters = Undefined;
				Result = DriverHandler.RunCommand(CommandParameters.Command, CommandParameters.InputParameters,
					Output_Parameters, DriverObject, CommandParameters.Parameters, TempConnectionParameters);
				If Not Result Then
					Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
				EndIf;
				ExecutionResult = New Structure("Result, Output_Parameters", Result, Output_Parameters);
				ExecuteNotifyProcessing(CommandParameters.AlertOnEnd, ExecutionResult);
			EndIf;
		EndIf
	EndIf;
	
EndProcedure

// Start executing additional command to driver not requiring preliminary device connection in system.
//
Procedure StartExecuteAdditionalCommand(AlertOnEnd, Command, InputParameters, ID, Parameters) Export
	
	// Search for enabled device.
	ConnectedDevice = GetConnectedDevice(glPeripherals.PeripheralsConnectingParameters, ID);
	                                                       
	If ConnectedDevice = Undefined Then
		EquipmentData = EquipmentManagerServerCall.GetDeviceData(ID);
		CommandParameters = New Structure();
		CommandParameters.Insert("Command"           , Command);
		CommandParameters.Insert("InputParameters"  , InputParameters);
		CommandParameters.Insert("Parameters"         , Parameters);
		CommandParameters.Insert("EquipmentData", EquipmentData);
		CommandParameters.Insert("AlertOnEnd", AlertOnEnd);
		Notification = New NotifyDescription("StartAdditionalCommandExecutionEnd", ThisObject, CommandParameters);
		StartReceivingDriverObject(Notification, EquipmentData);
	Else
		// Report an error saying that the device is enabled.
		ErrorText = NStr("en='The equipment is connected. Before you start, the device must be disabled.';ru='Устройство подключено. Перед выполнением операции устройство должно быть отключено.'");
		Output_Parameters = New Array();
		Output_Parameters.Add(999);
		Output_Parameters.Add(ErrorText);
		Output_Parameters.Add(NStr("en='Installed';ru='Установлен'"));
		ExecutionResult = New Structure("Result, Output_Parameters", False, Output_Parameters);
		ExecuteNotifyProcessing(AlertOnEnd, ExecutionResult);
	EndIf;
	
EndProcedure

#EndRegion

#Region HelperProceduresAndFunctions

// Function called during the system work start.
// Prepares mechanism data.
Function OnStart() Export

	If glPeripherals = Undefined Then
		glPeripherals = New Structure("PeripheralsDrivers,
												|PeripheralsConnectingParameters,
												|LastSlipReceipt,
												|DMDevicesTable,
												|ManagerDriverParameters",
												 New Map(),
												 New Array(),
												 "",
												 New Structure(),
												 New Structure());
	EndIf;
	
#If Not WebClient Then
	ResetMarkedDrivers();
#EndIf
	
EndFunction

// Function called during the system work start.
// Prepares mechanism data.
Function BeforeExit() Export
	
	DisableAllEquipment();
	
EndFunction

// Set equipment.
// 
Procedure ExecuteEquipmentSetup(ID) Export

	Result = True;
	
	DataDevice = EquipmentManagerClientReUse.GetDeviceData(ID);
	FormParameters = New Structure("EquipmentParameters", DataDevice.Parameters);
	FormParameters.Insert("ID", ID);       
	FormParameters.Insert("HardwareDriver", DataDevice.HardwareDriver);  
	
	SettingsForm = "SettingsFormUniversalDriver";
	
	DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(DataDevice.DriverHandler, Not DataDevice.AsConfigurationPart);
		
	If Not DriverHandler = PeripheralsUniversalDriverClient AND 
		Not DriverHandler = PeripheralsUniversalDriverClientAsynchronously Then
		SettingsForm = EquipmentManagerClientReUse.GetParametersSettingFormName(String(DataDevice.DriverHandler));
	EndIf;
		
	If Not IsBlankString(SettingsForm) Then
		Handler = New NotifyDescription("ExecuteEquipmentSettingEnd", ThisObject);
		OpenForm("CommonForm." + SettingsForm, FormParameters,,,  ,, Handler, FormWindowOpeningMode.LockWholeInterface);
	Else
		CommonUseClientServer.MessageToUser(NStr("en='An error occurred while initializing the driver customization form.';ru='Произошла ошибка инициализации формы настройки драйвера.'")); 
	EndIf;
	
EndProcedure

// End equipment setting.
//
Procedure ExecuteEquipmentSettingEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		CompletionResult = False;
		If Result.Property("ID") AND Result.Property("EquipmentParameters") Then
			CompletionResult = EquipmentManagerServerCall.SaveDeviceParameters(Result.ID, Result.EquipmentParameters);
		EndIf;
		
		If CompletionResult Then 
			RefreshReusableValues();
		Else
			ErrorInfo = NStr("en='Failed to save the device parameters.';ru='Не удалось сохранить параметры устройства.'");
			CommonUseClientServer.MessageToUser(ErrorInfo);
		EndIf;
		
	EndIf;
	
EndProcedure

// Saves user settings of peripherals.
//
Procedure SaveUserSettingsOfPeripherals(SettingsList) Export

	EquipmentManagerServerCall.SaveUserSettingsOfPeripherals(SettingsList);

EndProcedure

// Procedure generates the delay of the specified duration.
//
// Parameters:
//  Time - <Number>
//        - Delay duration in seconds.
//
Procedure Pause(Time) Export

	CompletionTime = CurrentDate() + Time;
	While CurrentDate() < CompletionTime Do
	EndDo;

EndProcedure

// Cuts the passed row by the field length if the field is too short - adds spaces.
//
Function ConstructField(Text, FieldLenght) Export
	
	TextFull = Left(Text, FieldLenght);
	While StrLen(TextFull) < FieldLenght Do
		TextFull = TextFull + " ";
	EndDo;
	
	Return TextFull;
	
EndFunction

// Convert row list to array.
//
Function ConvertStringToArrayList(Source) Export
	
	IntermediateStructure = New Structure(Source);
	Receiver = New Array;
	
	For Each KeyAndValue IN IntermediateStructure Do
		Receiver.Add(KeyAndValue.Key);
	EndDo;
	
	Return Receiver;
	
EndFunction

// Returns slip check template by the template name.
//
Function GetSlipReceipt(TemplateName, SlipReceiptWidth, Parameters, PINAuthorization = False) Export

	Return EquipmentManagerClientReUse.GetSlipReceipt(TemplateName, SlipReceiptWidth, Parameters, PINAuthorization);

EndFunction

Procedure BeginInstallFileSystemExtensionEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		BeginInstallFileSystemExtension();
	EndIf;
	
EndProcedure

Procedure BeginEnableExtensionFileOperationsEnd(Attached, AdditionalParameters) Export
	
	If Not Attached AND AdditionalParameters.OfferInstallation Then
		Notification = New NotifyDescription("BeginInstallFileSystemExtensionEnd", ThisObject, AdditionalParameters);
		MessageText = NStr("en='To continue work, you need to install 1C: Enterprise web client extension. Install?';ru='Для продолжении работы необходимо установить расширение для веб-клиента ""1С:Предприятие"". Установить?'");
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo); 
	EndIf;
	
	If AdditionalParameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, Attached);
	EndIf
	
EndProcedure

// Check if extension of work with Files is available.
// 
Procedure CheckFileOperationsExtensionAvailability(AlertOnEnd, OfferInstallation = True) Export
	
	#If Not WebClient Then
	// The extension is always enabled in thin and thick client.
	ExecuteNotifyProcessing(AlertOnEnd, True);
	Return;
	#EndIf
	
	AdditionalParameters = New Structure("AlertOnEnd, OfferSetting", AlertOnEnd, OfferInstallation);
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, AdditionalParameters);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

// End selecting driver file.
//
Procedure DriverFileChoiceEnd(SelectedFiles, Parameters) Export
	
	If TypeOf(SelectedFiles) = Type("Array") AND SelectedFiles.Count() > 0 
		AND Parameters.AlertOnSelection <> Undefined Then
		ExecuteNotifyProcessing(Parameters.AlertOnSelection, SelectedFiles[0]);
	EndIf;
	
EndProcedure

// The function starts selecting a driver file for further import.
//
Procedure StartDriverFileSelection(AlertOnSelection) Export 
	
	Result = False;
	FullFileName = "";
	
	FileOpeningDialog = New FileDialog(FileDialogMode.Open);
	FileOpeningDialog.Multiselect = False;
	FileOpeningDialog.Title = NStr("en='Select a driver file';ru='Выберите файл драйвера'");
	FileOpeningDialog.Filter = NStr("en='Driver file';ru='Файл драйвера'") + ?(EquipmentManagerClientReUse.IsLinuxClient(), "(*.zip)|*.zip", "(*.zip, *.exe)| *.zip; *.exe");  
	
	Parameters = New Structure("AlertOnSelection", AlertOnSelection);
	Notification = New NotifyDescription("DriverFileChoiceEnd", ThisObject, Parameters);
	
	FileOpeningDialog.Show(Notification);
	
EndProcedure

// End selecting a file
//
Procedure StartFileSelectionEndExtension(IsSet, AdditionalParameters) Export
	
	If IsSet Then
		Dialog = New FileDialog(FileDialogMode.Open);
		Dialog.Multiselect = False;
		Dialog.FullFileName = AdditionalParameters.FileName;
		Dialog.Show(AdditionalParameters.AlertOnSelection);
	EndIf;
	
EndProcedure

// The function starts a file selection.
//
Procedure StartFileSelection(AlertOnSelection, Val FileName) Export
	
	CommandParameters = New Structure("AlertOnSelection, FileName", AlertOnSelection, FileName);
	Notification = New NotifyDescription("StartFileSelectionEndExtension", ThisObject, CommandParameters);
	EquipmentManagerClient.CheckFileOperationsExtensionAvailability(Notification);
	StandardProcessing = False;
	
EndProcedure

// The procedure selects a peripheral from the available ones associated with the current work place.
//
Procedure OfferSelectDevice(SelectionNotification, EquipmentType, HeaderTextSelect, 
	NotConnectedMessage = "", MessageNotSelected = "", WithoutMessages = False, MessageText = "") Export
	
	If Not EquipmentManagerClient.RefreshClientWorkplace() Then
		MessageText = NStr("en='It is required to select a work place of the current peripheral session in advance.';ru='Предварительно необходимо выбрать рабочее место подключаемого оборудования текущего сеанса.'");
		If Not WithoutMessages Then
		      CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		Return;
	EndIf;
	
	ListOfAvailableDevices = EquipmentManagerServerCall.GetEquipmentList(EquipmentType);
	
	If ListOfAvailableDevices.Count() = 0 Then
		If Not IsBlankString(NOTConnectedMessage) Then
			If WithoutMessages Then
				MessageText = NotConnectedMessage;
			Else
				CommonUseClientServer.MessageToUser(NOTConnectedMessage);
			EndIf;
		EndIf;
	Else
		DeviceList = New ValueList();
		For Each Device IN ListOfAvailableDevices Do
			DeviceList.Add(Device.Ref, Device.Description);
		EndDo;
		If DeviceList.Count() = 1 Then
			ID = DeviceList[0].Value;
			ExecuteNotifyProcessing(SelectionNotification, ID); 
		Else
			Context = New Structure;
			Context.Insert("NextAlert", SelectionNotification);
			Context.Insert("MessageNotSelected"  , ?(IsBlankString(MessageNotSelected), NotConnectedMessage, MessageNotSelected));
			Context.Insert("WithoutMessages"       , WithoutMessages);
			NotifyDescription = New NotifyDescription("OfferSelectDeviceEnd", ThisObject, Context);
			DeviceList.ShowChooseItem(NOTifyDescription, HeaderTextSelect);
		EndIf;
	EndIf;
	
	Return;
	
EndProcedure

Procedure OfferSelectDeviceEnd(Result, Parameters) Export
	
	If Result = Undefined Then
		If Parameters <> Undefined Then
			If Parameters.WithoutMessages Then
				ExecuteNotifyProcessing(Parameters.NextAlert, Undefined);
			ElsIf Not IsBlankString(Parameters.MessageNotSelected) Then
				CommonUseClientServer.MessageToUser(Parameters.MessageNotSelected);
			EndIf;
		EndIf;
	Else
		If Parameters <> Undefined AND Parameters.NextAlert <> Undefined Then
			ID = Result.Value;
			ExecuteNotifyProcessing(Parameters.NextAlert, ID);
		EndIf;
	EndIf;
	
EndProcedure

// Function provides a dialog of work place selection.
// 
Procedure OfferWorkplaceSelection(NotificationProcessing, ClientID = "") Export

	Result = False;
	Workplace = "";
	
	FormParameters = New Structure();
	FormParameters.Insert("ClientID", ClientID);
	
	OpenForm("Catalog.Peripherals.Form.WorkplaceChoiceForm", FormParameters,,,  ,, NotificationProcessing, FormWindowOpeningMode.LockWholeInterface);

EndProcedure

// End selecting work place.
//
Procedure OfferWorkplaceSelectionEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") AND Result.Property("Workplace") Then 
		EquipmentManagerClient.SetWorkplace(Result.Workplace);
	EndIf;
		
EndProcedure

// Function sets a work place.
// 
Procedure SetWorkplace(Workplace) Export
	
	EquipmentManagerServerCall.SetClientWorkplace(Workplace);
	Notify("CurrentSessionWorkplaceChanged", Workplace);
	
EndProcedure

// Updates a computer name in a parameter of session "ClientWorkplace".
//
Function RefreshClientWorkplace() Export
	
	Result = True;
	
	Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	
	If Not ValueIsFilled(Workplace) Then
		SystemInfo = New SystemInfo();
		
		WorkplacesArray = EquipmentManagerClientReUse.FindWorkplacesById(Upper(SystemInfo.ClientID));
		If WorkplacesArray.Count() = 0 Then
			Parameters = New Structure;
			Parameters.Insert("ComputerName");
			Parameters.Insert("ClientID");
			
			#If Not WebClient Then
				Parameters.ComputerName = ComputerName();
			#EndIf
			
			Parameters.ClientID = Upper(SystemInfo.ClientID);
			Workplace = EquipmentManagerServerCall.CreateClientWorkplace(Parameters);
		Else
			Workplace = WorkplacesArray[0];
		EndIf;
		
	EndIf;
	
	If Result
		AND Workplace <> EquipmentManagerClientReUse.GetClientWorkplace() Then
		EquipmentManagerServerCall.SetClientWorkplace(Workplace);
		Notify("CurrentSessionWorkplaceChanged", Workplace);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region WorkWithElectronicScalesProceduresAndFunctions

// Receives weight from electronic scales.
// UUID - form identifiers.
// AlertOnGetWeight - alert on weighing end and weight pass.
//
Procedure StartWeightReceivingFromElectronicScales(AlertOnGetWeight, UUID) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnGetWeight);
	Context.Insert("UUID" , UUID);
	
	NotifyDescription = New NotifyDescription("StartWeightReceivingFromElectronicScalesEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "ElectronicScales",
		NStr("en='Choose electronic scales';ru='Выберите электронные весы'"), NStr("en='Electronic scales are not connected.';ru='Электронные весы не подключены.'"), NStr("en='Electronic scales are not selected.';ru='Электронные весы не выбраны.'"));
	
EndProcedure

// Procedure of weight receipt from electronic scales ending.
// 
Procedure StartWeightReceivingFromElectronicScalesEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable scales
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	If Result Then  
		
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		// Attempt to get a weight
		Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, "GetWeight", InputParameters, Output_Parameters);    
		If Result Then
			Weight = Output_Parameters[0]; // Weight is received.
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, Weight);
			EndIf;
		Else
			MessageText = NStr("en='An error occurred while using electronic scales.
		|Additional description: |%Additional description%';ru='При использовании электронных весов произошла ошибка.
		|Дополнительное описание: |%ДополнительноеОписание%'");
			MessageText = StrReplace(MessageText, "%AdditionalDetails%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
		// Disable scales
		EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
		
	Else
		// An error occurred while connecting weights
		MessageText = NStr("en='An error occurred while enabling electronic scales.
		|Additional description: %AdditionalDetails%';ru='При подключении электронных весов произошла ошибка.
		|Дополнительное описание: %ДополнительноеОписание%'");
		MessageText = StrReplace(MessageText, "%AdditionalDetails%", ErrorDescription);
		CommonUseClientServer.MessageToUser(ErrorDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsSTSD

// Start exporting data in the data collection terminal.
// UUID - form identifiers.
// AlertOnDataExport - alert on data export end.
//
Procedure StartDataExportVTSD(AlertOnDataExport, UUID, ProductsExportTable) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnDataExport);
	Context.Insert("UUID" , UUID);
	Context.Insert("ProductsExportTable"  , ProductsExportTable);
	
	NotifyDescription = New NotifyDescription("StartDataExportToDCTEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "DataCollectionTerminal",
		NStr("en='Select the data collector';ru='Выберите терминал сбора данных'"), NStr("en='Data collection terminal is not enabled.';ru='Терминал сбора данных не подключен.'"));
	
EndProcedure

Procedure StartDataExportToDCTEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable DCT
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		InputParameters  = New Array();
		Output_Parameters = Undefined;
				
		// Convert structures array to values list array with the predefined and fixed fields order:
		// 0 - Barcode
		// 1 - ProductsAndServices
		// 2 - MeasurementUnit
		// 3 - ProductsAndServicesCharacteristic
		// 4 - ProductsAndServicesSeries
		// 5 - Quality
		// 6 - Price
		// 7 - Count
		DCTArray = New Array;
		For Each curRow IN Parameters.ProductsExportTable Do
			If curRow.Property("ProductsAndServices") Then
				ProductsAndServicesDescription = String(curRow.ProductsAndServices);
			ElsIf curRow.Property("Description") Then
				ProductsAndServicesDescription = curRow.Description;
			Else
				ProductsAndServicesDescription = "";
			EndIf;
			DCTArrayRow = New ValueList; // Not an array for saving compatibility with maintenance processors.
			DCTArrayRow.Add(?(curRow.Property("Barcode")                   , curRow.Barcode, ""));
			DCTArrayRow.Add(ProductsAndServicesDescription);
			DCTArrayRow.Add(?(curRow.Property("MeasurementUnit")           , curRow.MeasurementUnit, ""));
			DCTArrayRow.Add(?(curRow.Property("ProductsAndServicesCharacteristic") , curRow.ProductsAndServicesCharacteristic, ""));
			DCTArrayRow.Add(?(curRow.Property("ProductsAndServicesSeries")          , curRow.ProductsAndServicesSeries, ""));
			DCTArrayRow.Add(?(curRow.Property("Quality")                   , curRow.Quality, ""));
			DCTArrayRow.Add(?(curRow.Property("Price")                       , curRow.Price, 0));
			DCTArrayRow.Add(?(curRow.Property("Count")                 , curRow.Count, 0));
			DCTArray.Add(DCTArrayRow);
		EndDo;
				
		InputParameters.Add("Items");
		InputParameters.Add(DCTArray);
				
		Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, "ImportDirectory", InputParameters, Output_Parameters);
		If Not Result Then
			MessageText = NStr("en='An error occurred while exporting data to the data collection terminal.
		|%ErrorDetails%
		|Data is not exported to the data collection terminal.';ru='При выгрузке данных в терминал сбора данных произошла ошибка.
		|%ОписаниеОшибки%
		|Данные в терминал сбора данных не выгружены.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			EndIf;
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
			
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDetails%
		|Data is not exported to the data collection terminal.';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%
		|Данные в терминал сбора данных не выгружены.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
		
EndProcedure

// Start importing data from data collection terminal.
// UUID - form identifiers.
// AlertOnImportData - alert on data export end.
// CollapseData - minimize data on import (group by barcode and quantity summary).
//
Procedure StartImportDataFromDCT(AlertOnImportData, UUID, CollapseData = True) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnImportData);
	Context.Insert("UUID" , UUID);
	Context.Insert("CollapseData"       , CollapseData);
	
	NotifyDescription = New NotifyDescription("StartImportDataFromDCTEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "DataCollectionTerminal",
		NStr("en='Select the data collector';ru='Выберите терминал сбора данных'"), NStr("en='Data collection terminal is not enabled.';ru='Терминал сбора данных не подключен.'"));
		
EndProcedure

Procedure StartImportDataFromDCTEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable DCT
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, "ExportDocument", InputParameters, Output_Parameters);
		
		If Result Then
			
			TableImportFromDCT = New Array();       
			DataTable = New Map();
			
			For IndexOf = 0 To Output_Parameters[0].Count()/2 - 1 Do
				Barcode    = Output_Parameters[0][IndexOf * 2 + 0];
				Quantity = Number(?(Output_Parameters[0][IndexOf * 2 + 1] <> Undefined, Output_Parameters[0][IndexOf * 2 + 1], 0));
				If Parameters.CollapseData Then
					Data = DataTable.Get(Barcode);
					If Data = Undefined Then
						DataTable.Insert(Barcode, Quantity)
					Else
						DataTable.Insert(Barcode, Data + Quantity)
					EndIf;
				Else
					TableImportFromDCT.Add(New Structure("Barcode, Quantity", Barcode, Quantity));
				EndIf;
			EndDo;
					
			If Parameters.CollapseData Then
				For Each Data  IN DataTable Do
					TableImportFromDCT.Add(New Structure("Barcode, Quantity", Data.Key, Data.Value));
				EndDo
			EndIf;
			
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, TableImportFromDCT);
			EndIf;
			
		Else
			MessageText = NStr("en='An error occurred while exporting data from the data collection terminal.
		|%ErrorDetails%
		|Data from the data collection terminal is not imported.';ru='При загрузке данных из терминала сбора данных произошла ошибка.
		|%ОписаниеОшибки%
		|Данные из терминала сбора данных не загружены.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDetails%
		|Data from the data collection terminal is not imported.';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%
		|Данные из терминала сбора данных не загружены.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start clearing data in the data collection terminal.
// UUID - form identifiers.
// AlertWhenClearingData - alert on data clearing end.
//
Procedure StartClearingDataVTSD(AlertWhenClearingData, UUID) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertWhenClearingData);
	Context.Insert("UUID" , UUID);
	
	NotifyDescription = New NotifyDescription("StartClearingDataToDCTEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "DataCollectionTerminal",
		NStr("en='Select the data collector';ru='Выберите терминал сбора данных'"), NStr("en='Data collection terminal is not enabled.';ru='Терминал сбора данных не подключен.'"));
		
EndProcedure

Procedure StartClearingDataToDCTEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	// Enable DCT
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, "ClearTable", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en='An error occurred while clearing data in the data collection terminal.
		|%ErrorDescription%';ru='При очистке данных в терминале сбора данных произошла ошибка.
		|%ОписаниеОшибки%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			EndIf;
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDetails%
		|Data is not exported to the data collection terminal.';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%
		|Данные в терминал сбора данных не выгружены.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithPOSProceduresAndFunctions

// Start enabling POS terminal. 
// If POS terminal does not support tickets printing on terminal, fiscal register is
// enabled for printing.
//
// Incoming parameters: 
//   UUID - form identifiers.
//   AlertOnEnd - alert on end enabling POS terminal.
//   POSTerminal - POS terminal will be selected if it is not specified.
// Outgoing parameters: - 
//   Structure with the following attributes.
//     EnabledDeviceIdentifierET - Identifier of enabled POS terminal.
//     FREnableDeviceID - Identifier of the enabled fiscal register.
//     ReceiptsPrintOnTerminal - supports tickets printing on the
//                                  terminal if True FRConnectedDeviceIdentifier = Undefined.
// After you use it, it is required to disable enabled devices using DisablePOSTerminal method.
//
Procedure StartEnablePOSTerminal(AlertOnEnd, UUID, POSTerminal = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnEnd);
	Context.Insert("UUID" , UUID);
	
	If ValueIsFilled(POSTerminal) Then
		EnablePOSTerminalEnd(POSTerminal, Context);
	Else
		NotifyDescription = New NotifyDescription("EnablePOSTerminalEnd", ThisObject, Context);
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "POSTerminal",
			NStr("en='Select the POS terminal';ru='Выберите эквайринговый терминал'"), NStr("en='POS-Terminal is not connected.';ru='Эквайринговый терминал не подключен.'"));
	EndIf;
	
EndProcedure

Procedure EnablePOSTerminalEnd(DeviceIdentifierET, Parameters) Export
	
	ErrorDescription = "";
	
	ResultET = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, DeviceIdentifierET, ErrorDescription);
	
	If Not ResultET Then
		MessageText = NStr("en='When POS terminal connection there
		|was error: ""%ErrorDescription%"".
		|The operation was not performed.';ru='При подключении эквайрингового
		|терминала произошла ошибка: ""%ОписаниеОшибки%"".
		|Операция не была проведена.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		
		InputParameters = New Array();
		Output_Parameters = Undefined;
		
		ResultET = EquipmentManagerClient.RunCommand(DeviceIdentifierET, "PrintSlipOnTerminal", InputParameters, Output_Parameters);
		
		If Output_Parameters.Count() > 0 AND Output_Parameters[0] Then
			If Parameters.NextAlert <> Undefined Then
				CompletionParameters = New Structure;
				CompletionParameters.Insert("UUID"                , Parameters.UUID);
				CompletionParameters.Insert("EnabledDeviceIdentifierET" , DeviceIdentifierET);
				CompletionParameters.Insert("ReceiptsPrintOnTerminal"             , True);
 				EquipmentManagerClient.Pause(1);
				ExecuteNotifyProcessing(Parameters.NextAlert, CompletionParameters);
			EndIf;
		Else
			Parameters.Insert("EnabledDeviceIdentifierET" , DeviceIdentifierET);
			Parameters.Insert("ReceiptsPrintOnTerminal"             , False);
			NotifyDescription = New NotifyDescription("EnableFiscalRegistrarEnd", ThisObject, Parameters);
			EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
					NStr("en='Select a fiscal register to print POS receipts.';ru='Выберите фискальный регистратор для печати эквайринговых чеков'"), NStr("en='Fiscal register for printing acquiring receipts is not enabled.';ru='Фискальный регистратор для печати эквайринговых чеков не подключен.'"));
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure EnableFiscalRegistrarEnd(DeviceIdentifierFR, Parameters) Export
	
	ErrorDescription = "";
	
	ResultFR = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, DeviceIdentifierFR, ErrorDescription);
	
	If Not ResultFR Then
		
		// ET device disconnect
		If Not Parameters.EnabledDeviceIdentifierET = Undefined Then
			EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, Parameters.EnabledDeviceIdentifierET);
		EndIf;
			
		MessageText = NStr("en='When fiscal registrar connection there
		|was error: ""%ErrorDescription%"".
		|Operation can not be executed.';ru='При подключении фискального регистратора произошла ошибка:
		|""%ОписаниеОшибки%"".
		|Операция по карте не была выполнена.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
		
	Else
		If Parameters.NextAlert <> Undefined Then
			CompletionParameters = New Structure;
			CompletionParameters.Insert("UUID"                , Parameters.UUID);
			CompletionParameters.Insert("EnabledDeviceIdentifierET" , Parameters.EnabledDeviceIdentifierET);
			CompletionParameters.Insert("ReceiptsPrintOnTerminal"             , Parameters.ReceiptsPrintOnTerminal);
			CompletionParameters.Insert("FREnableDeviceID" , DeviceIdentifierFR);
			ExecuteNotifyProcessing(Parameters.NextAlert, CompletionParameters);
		EndIf;
	EndIf;
	
EndProcedure

// Disable the enabled POS terminal. 
// If POS terminal does not support tickets printing on terminal, fiscal register
// is enabled for printing.
// This procedure also disconnects
// it/ Incoming parameters:  
//   Parameters  - Structure with the following attributes.
//     EnabledDeviceIdentifierET - Identifier of enabled POS terminal.
//     FREnableDeviceID - Identifier of the enabled fiscal register.
//     ReceiptsPrintOnTerminal - supports tickets printing on the
//                                  terminal if True FRConnectedDeviceIdentifier = Undefined.
//  UUID - form identifiers.
//
Procedure DisablePOSTerminal(UUID, Parameters) Export
	
	If Not Parameters.ReceiptsPrintOnTerminal AND Not Parameters.FREnableDeviceID = Undefined Then
		EquipmentManagerClient.DisableEquipmentById(UUID, Parameters.FREnableDeviceID);
	EndIf;
	
	If Not Parameters.EnabledDeviceIdentifierET = Undefined Then
		EquipmentManagerClient.DisableEquipmentById(UUID, Parameters.EnabledDeviceIdentifierET);
	EndIf;
	 
EndProcedure

Procedure ExecuteTotalsRevisionPOSTerminalEnd(Result, Parameters) Export
	
	If Not TypeOf(Result) = Type("Structure") Then
		MessageText = NStr("en='An error occurred while executing operation.';ru='При выполнении операции произошла ошибка.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	UUID = Result.UUID;
	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	
	// Executing the operation on POS terminal
	ResultET = EquipmentManagerClient.RunCommand(Result.EnabledDeviceIdentifierET, "Settlement", InputParameters, Output_Parameters);
	
	If Not ResultET Then
		MessageText = NStr("en='When operation execution there
		|was error: ""%ErrorDescription%"".
		|Totals reconciliation is not executed.';ru='При выполнении операции возникла ошибка:
		|""%ОписаниеОшибки%"".
		|Отмена по карте не была произведена.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
		CommonUseClientServer.MessageToUser(MessageText);
	Else
		
		SlipReceiptText = Output_Parameters[0][1];
		If Not IsBlankString(SlipReceiptText) Then
			glPeripherals.Insert("LastSlipReceipt", SlipReceiptText);
		EndIf;
	
		If Not Result.ReceiptsPrintOnTerminal AND Not Result.FREnableDeviceID = Undefined Then
			If Not IsBlankString(SlipReceiptText) Then
				
				InputParameters = New Array();
				InputParameters.Add(SlipReceiptText);
				Output_Parameters = Undefined;
				ResultFR = EquipmentManagerClient.RunCommand(Result.FREnableDeviceID, "PrintText", InputParameters, Output_Parameters);
				
				If Not ResultFR Then
					MessageText = NStr("en='An error occurred while printing
		|a slip receipt: ""%ErrorDetails%"".';ru='При печати слип чека
		|возникла ошибка: ""%ОписаниеОшибки%"".'");
					MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
					CommonUseClientServer.MessageToUser(MessageText);
				EndIf;
			Else
				MessageText = NStr("en='Totals reconciliation is successfully executed.';ru='Операция сверки итогов успешно выполнена.'");
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
	EndIf;
	
	EquipmentManagerClient.DisablePOSTerminal(UUID, Result);
	
EndProcedure

// Check totals on POS terminal.
// If POS terminal does not support tickets printing on terminal, fiscal register
// is enabled for printing.
//
// Incoming parameters: 
//   UUID - form identifiers.
//
Procedure RunTotalsOnPOSTerminalRevision(UUID) Export
	
	NotifyDescription = New NotifyDescription("ExecuteTotalsRevisionPOSTerminalEnd", ThisObject);
	EquipmentManagerClient.StartEnablePOSTerminal(NOTifyDescription, UUID);
	
EndProcedure

#EndRegion

#Region WorkWithScalesWithLabelsPrintingProceduresAndFunctions

Procedure StartDataExportToScalesWithLabelsPrinting(AlertOnDataExport, ClientID, DeviceIdentifier = Undefined, ProductsExportTable, PartialExport = False) Export
	
	If ProductsExportTable.Count() = 0 Then
		MessageText = NStr("en='There is no data to export!';ru='Нет данных для выгрузки!'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("NextAlert"    , AlertOnDataExport);
	Context.Insert("ClientID"   , ClientID);
	Context.Insert("ProductsExportTable" , ProductsExportTable);
	Context.Insert("PartialExport"      , PartialExport);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartDataExportToScalesWithLablesPrintingEnd", ThisObject, Context);
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "LabelsPrintingScales",
			NStr("en='Select the label printing scales';ru='Выберите весы с печатью этикеток'"), NStr("en='Scales with labels printing are not enabled.';ru='Весы с печатью этикеток не подключены.'"));
	Else
		StartDataExportToScalesWithLablesPrintingEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartDataExportToScalesWithLablesPrintingEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartDataExportToScalesWithLabelsPrintingFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NOTifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartDataExportToScalesWithLabelsPrintingFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartDataExportToScalesWithLabelsPrintingFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en='The operation is unavailable without installed 1C: Enterprise web client extension.';ru='Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".'");
		CommonUseClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.ClientID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		ProductsArray = New Array;
		For Each TSRow IN Parameters.ProductsExportTable Do
			ArrayElement = New Structure("PLU, Code, Barcode, Description, DescriptionFull, Price", 0, 0, "", "" , 0);
			ArrayElement.PLU = TSRow.PLU;
			ArrayElement.Code = TSRow.Code;
			ArrayElement.Description = ?(TSRow.Property("ProductsAndServices"), String(TSRow.ProductsAndServices), ?(TSRow.Property("Description"), String(TSRow.Description), ""));
			ArrayElement.DescriptionFull = ?(TSRow.Property("DescriptionFull"), String(TSRow.DescriptionFull), "");
			ArrayElement.DescriptionFull = ?(IsBlankString(ArrayElement.DescriptionFull), ArrayElement.Description, ArrayElement.DescriptionFull); 
			ArrayElement.Price = TSRow.Price;
			ProductsArray.Add(ArrayElement);
		EndDo;
		
		InputParameters  = New Array;
		InputParameters.Add(ProductsArray);
		InputParameters.Add(Parameters.PartialExport); // Partial export.
		Output_Parameters = Undefined;
			
		Result = EquipmentManagerClient.RunCommand(Parameters.DeviceIdentifier, "ExportProducts", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en='An error occurred while exporting data to equipment.
		|%ErrorDescription%
		|Data is not exported.';ru='При выгрузке данных в оборудование произошла ошибка.
		|%ОписаниеОшибки%
		|Данные не выгружены.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			Else
				MessageText = NStr("en='The data has been exported successfully.';ru='Данные выгружены успешно.'");
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(Parameters.ClientID, Parameters.DeviceIdentifier);
		
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDescription%
		|Data is not exported.';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%
		|Данные не выгружены.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

Procedure StartClearingProductsInScalesWithLabelsPrinting(AlertWhenClearingData, ClientID, DeviceIdentifier = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"  , AlertWhenClearingData);
	Context.Insert("ClientID" , ClientID);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartClearingProductsInScalesWithLabelsPrintingEnd", ThisObject, Context);
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "LabelsPrintingScales",
			NStr("en='Select the label printing scales';ru='Выберите весы с печатью этикеток'"), NStr("en='Scales with labels printing are not enabled.';ru='Весы с печатью этикеток не подключены.'"));
	Else
		StartClearingProductsInScalesWithLabelsPrintingEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartClearingProductsInScalesWithLabelsPrintingEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.ClientID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, "ClearBase", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en='An error occurred while clearing data to equipment.
		|%ErrorDescription%';ru='При очистке данных в оборудование произошла ошибка.
		|%ОписаниеОшибки%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			Else
				MessageText = NStr("en='Data is successfully cleared.';ru='Очистка данных успешно завершена.'");
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
			
		EquipmentManagerClient.DisableEquipmentById(Parameters.ClientID, DeviceIdentifier);
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDescription%';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithEquipmentCRProceduresAndFunctionsOffline

// Clears products in CR Offline.
//
Procedure StartProductsCleaningInCROffline(AlertWhenClearingData, UUID, DeviceIdentifier = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertWhenClearingData);
	Context.Insert("UUID" , UUID);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartCleaningProductsCROfflineEnd", ThisObject, Context);
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "CashRegistersOffline",
			NStr("en='Select CR Offline';ru='Выберите ККМ Offline'"), NStr("en='Offline CRs are not connected.';ru='ККМ Offline не подключены.'"));
	Else
		StartCleaningProductsCROfflineEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartCleaningProductsCROfflineEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartCleaningProductsToCROfflineFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NOTifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartCleaningProductsToCROfflineFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartCleaningProductsToCROfflineFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en='The operation is unavailable without installed 1C: Enterprise web client extension.';ru='Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".'");
		CommonUseClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		Status(NStr("en='Products clearing in CR Offline is in progress...';ru='Выполняется очистка товаров в ККМ Offline...'"));
		
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		
		Result = EquipmentManagerClient.RunCommand(Parameters.DeviceIdentifier, "ClearBase", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en='An error occurred while clearing data to equipment.
		|%ErrorDescription%';ru='При очистке данных в оборудование произошла ошибка.
		|%ОписаниеОшибки%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, Parameters.DeviceIdentifier);
		
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, Result);
		EndIf;
			
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDescription%';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Export table with data to CR Offline.
// 
Procedure StartDataExportToCROffline(AlertOnDataExport, UUID, DeviceIdentifier = Undefined,
	ProductsExportTable, PartialExport = False) Export
	
	If ProductsExportTable.Count() = 0 Then
		MessageText = NStr("en='There is no data to export!';ru='Нет данных для выгрузки!'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnDataExport);
	Context.Insert("UUID" , UUID);
	Context.Insert("ProductsExportTable"  , ProductsExportTable);
	Context.Insert("PartialExport"       , PartialExport);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartDataExportToCROfflineEnd", ThisObject, Context);
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "CashRegistersOffline",
			NStr("en='Select CR Offline';ru='Выберите ККМ Offline'"), NStr("en='Offline CRs are not connected.';ru='ККМ Offline не подключены.'"));
	Else
		StartDataExportToCROfflineEnd(DeviceIdentifier, Context);
	EndIf;
	
EndProcedure

Procedure StartDataExportToCROfflineEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartDataExportToCROfflineFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NOTifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartDataExportToCROfflineFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartDataExportToCROfflineFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en='The operation is unavailable without installed 1C: Enterprise web client extension.';ru='Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".'");
		CommonUseClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		
		Status(NStr("en='Products export to CR Offline is in progress...';ru='Выполняется выгрузка товаров в ККМ Offline...'")); 
		
		ProductsArray = New Array;
		For Each TSRow IN Parameters.ProductsExportTable Do
			ArrayElement = New Structure("Code, SKU, Barcode, Description, DescriptionFull, MeasurementUnit, Price, Balance, WeightProduct");
			ArrayElement.Code                = TSRow.Code;
			ArrayElement.SKU            = ?(TSRow.Property("SKU"), TSRow.SKU, "");
			ArrayElement.Barcode           = TSRow.Barcode;
			ArrayElement.Description       = TSRow.Description;
			ArrayElement.DescriptionFull = TSRow.DescriptionFull;
			ArrayElement.MeasurementUnit   = TSRow.MeasurementUnit;
			ArrayElement.Price               = TSRow.Price;
			ArrayElement.Balance            = ?(TSRow.Property("Balance"), TSRow.Balance, 0);
			ArrayElement.WeightProduct       = ?(TSRow.Property("WeightProduct"), TSRow.WeightProduct, False);
			ProductsArray.Add(ArrayElement);
		EndDo;
		
		InputParameters  = New Array;
		InputParameters.Add(ProductsArray);
		InputParameters.Add(Parameters.PartialExport); // Partial export.
		Output_Parameters = Undefined;
			
		Result = EquipmentManagerClient.RunCommand(Parameters.DeviceIdentifier, "ExportProducts", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en='An error occurred while exporting data to equipment.
		|%ErrorDescription%
		|Data is not exported.';ru='При выгрузке данных в оборудование произошла ошибка.
		|%ОписаниеОшибки%
		|Данные не выгружены.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, True);
			Else
				MessageText = NStr("en='The data has been exported successfully.';ru='Данные выгружены успешно.'");
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, Parameters.DeviceIdentifier);
		
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDescription%
		|Data is not exported.';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%
		|Данные не выгружены.'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start importing data from CR Offline.
// UUID - form identifiers.
// AlertOnImportData - alert on data export end.
//
Procedure StartImportRetailSalesReportFromCROffline(AlertOnImportData, UUID, DeviceIdentifier = Undefined) Export
	
	Context = New Structure;
	Context.Insert("NextAlert"     , AlertOnImportData);
	Context.Insert("UUID" , UUID);
	
	If DeviceIdentifier = Undefined Then
		NotifyDescription = New NotifyDescription("StartImportRetailSalesReportFromCROfflineEnd", ThisObject, Context);
		EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "CashRegistersOffline",
			NStr("en='Select CR Offline';ru='Выберите ККМ Offline'"), NStr("en='Offline CRs are not connected.';ru='ККМ Offline не подключены.'"));
	Else
		StartImportRetailSalesReportFromCROfflineEnd(DeviceIdentifier, Context);
	EndIf;
		
EndProcedure

Procedure StartImportRetailSalesReportFromCROfflineEnd(DeviceIdentifier, Parameters) Export
	
	Parameters.Insert("DeviceIdentifier", DeviceIdentifier);
#If WebClient Then
	NotifyDescription = New NotifyDescription("StartImportRetailSalesReportFromCROfflineFileExtensionEnd", ThisObject, Parameters);
	CheckFileOperationsExtensionAvailability(NOTifyDescription, False);
#Else
	// The extension is always enabled in thin and thick client.
	StartImportRetailSalesReportFromCROfflineFileExtensionEnd(True, Parameters);
#EndIf
	
EndProcedure

Procedure StartImportRetailSalesReportFromCROfflineFileExtensionEnd(Attached, Parameters) Export
	
	If Not Attached Then
		MessageText = NStr("en='The operation is unavailable without installed 1C: Enterprise web client extension.';ru='Данная операция не доступна без установленного расширения для веб-клиента ""1С:Предприятие"".'");
		CommonUseClientServer.MessageToUser(MessageText);
		If Parameters.NextAlert <> Undefined Then
			ExecuteNotifyProcessing(Parameters.NextAlert, False);
		EndIf;
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(Parameters.UUID, Parameters.DeviceIdentifier, ErrorDescription);
	
	If Result Then
		Status(NStr("en='Products import from CR Offline is in progress...';ru='Выполняется загрузка товаров из ККМ Offline...'"));
		
		InputParameters  = New Array;
		Output_Parameters = Undefined;
		
		Result = EquipmentManagerClient.RunCommand(Parameters.DeviceIdentifier, "ImportReport", InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en='An error occurred while importing data from CR Offline.
		|%ErrorDescription%';ru='При загрузка данных из ККМ Offline произошла ошибка.
		|%ОписаниеОшибки%'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			ProductsImportTable = Output_Parameters[0];
			If Parameters.NextAlert <> Undefined Then
				ExecuteNotifyProcessing(Parameters.NextAlert, ProductsImportTable);
			EndIf;
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(Parameters.UUID, Parameters.DeviceIdentifier);
		
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDescription%';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start outputting check box on report import.
//
Procedure StartCheckBoxReportImportedCROffline(UUID, DeviceIdentifier) Export;
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(UUID, DeviceIdentifier, ErrorDescription);
	
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		EquipmentManagerClient.RunCommand(DeviceIdentifier, "ReportImported", InputParameters, Output_Parameters);
	    EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
	Else
		MessageText = NStr("en='An error occurred when connecting the device.
		|%ErrorDescription%';ru='При подключении устройства произошла ошибка.
		|%ОписаниеОшибки%'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithPrintDevicesProceduresAndFunctions

// Function receives the width of row in characters.
//  
Function GetPrintingDeviceRowWidth(DeviceIdentifier) Export
	
	InputParameters  = Undefined;
	Output_Parameters = Undefined;
	
	Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, "GetLineLength", InputParameters, Output_Parameters);    
	
	If Result Then
		Return Output_Parameters[0];
	Else
		Return Undefined;
	EndIf;
	
EndFunction

#EndRegion

#Region WorkWithInputDevicesProceduresAndFunctions

// Defines correspondence between card code and template.
// Input:
// TracksData - Array containing rows of lane code. 3 items totally.
// PatternData - a structure containing template data:
// - Suffix
// - Prefix
// - BlocksDelimiter
// - CodeLength
// Output:
// True - code corresponds to template.
// Message to user on things that do not correspond.
Function CodeCorrespondsToMCTemplate(TracksData, PatternData) Export
	
	OneTrackExist = False;
	CheckPassed = True;
	
	For Iterator = 1 To 3 Do
		If PatternData["TrackAvailability"+String(Iterator)] Then
			OneTrackExist = True;
			curRow = TracksData[Iterator - 1];
			If Right(curRow, StrLen(PatternData["Suffix" + String(Iterator)])) <> PatternData["Suffix" + String(Iterator)] Then
				CommonUseClientServer.MessageToUser(NStr("en='Track';ru='Дорожка'") + Chars.NBSp + String(Iterator) 
					+ ". "+NStr("en='Card suffix does not match with template suffix.';ru='Суффикс карты не соответствует суффиксу шаблона.'"));
				CheckPassed = False;
			EndIf;
			
			If Left(curRow, StrLen(PatternData["Prefix" + String(Iterator)])) <> PatternData["Prefix" + String(Iterator)] Then
				CommonUseClientServer.MessageToUser(NStr("en='Track';ru='Дорожка'") + Chars.NBSp + String(Iterator) 
					+ ". " + NStr("en='Card prefix does not match with template prefix.';ru='Префикс карты не соответствует префиксу шаблона.'"));
				CheckPassed = False;
			EndIf;
			
			If Find(curRow, PatternData["BlocksDelimiter"+String(Iterator)]) = 0 Then
				CommonUseClientServer.MessageToUser(NStr("en='Track';ru='Дорожка'") + Chars.NBSp + String(Iterator) 
					+ ". "+NStr("en='Card blocks divider does not match with template blocks divider.';ru='Разделитель блоков карты не соответствует разделителю блоков шаблона.'"));
				CheckPassed = False;
			EndIf;
				
			If StrLen(curRow) <> PatternData["CodeLength"+String(Iterator)] Then
				CommonUseClientServer.MessageToUser(NStr("en='Track';ru='Дорожка'") + Chars.NBSp + String(Iterator) 
					+ ". " + NStr("en='Card code lenght does not match with template code lenght.';ru='Длина кода карты не соответствует длине кода шаблона.'"));
				CheckPassed = False;
			EndIf;
			
			If Not CheckPassed Then
				Return False;
			EndIf;
		EndIf;
	EndDo;
	
	If OneTrackExist Then 
		Return True;
	Else
		CommonUseClientServer.MessageToUser(NStr("en='In template not specified any available track.';ru='В шаблоне не указано ни одной доступной дорожки.'"));
		Return False;
	EndIf;
	
EndFunction

// Receives events from device.
//
Function GetEventFromDevice(DetailsEvents, ErrorDescription = "") Export
	
	Result = Undefined;
	
	// Searching for an event handler
	For Each Connection IN glPeripherals.PeripheralsConnectingParameters Do
						  
		If Connection.EventSource = DetailsEvents.Source
		 Or (IsBlankString(Connection.EventSource)
		   AND Connection.NamesEvents <> Undefined) Then
		   
		   // Look for device with the enabled event among the peripherals.
			Event = Connection.NamesEvents.Find(DetailsEvents.Event);
			If Event <> Undefined Then
				DriverObject = GetDriverObject(Connection);
				If DriverObject = Undefined Then
					// Error message prompting that the driver can not be imported.
					ErrorDescription = NStr("en='""%Description%"": Cannot export the peripheral driver.
		|Check if the driver is correctly installed and registered in the system.';ru='%Description%: Не удалось загрузить драйвер устройства.
		|Проверьте, что драйвер корректно установлен и зарегистрирован в системе.'");
					ErrorDescription = StrReplace(ErrorDescription, "%Description%", Connection.Description);
					Continue;
				EndIf;
				
				InputParameters  = New Array();
				InputParameters.Add(DetailsEvents.Event);
				InputParameters.Add(DetailsEvents.Data);
				Output_Parameters = Undefined;
				
				// Processing a message
				ProcessingResult = RunCommand(Connection.Ref, "ProcessEvent", InputParameters, Output_Parameters);
				
				If ProcessingResult Then
					// Notify 
					Result = New Structure();
					Result.Insert("EventName", Output_Parameters[0]);
					Result.Insert("Parameter",   Output_Parameters[1]);
					Result.Insert("Source",   "Peripherals");
				EndIf;
				
				// Notify driver on event processor end.
				InputParameters.Clear();
				InputParameters.Add(ProcessingResult);
				RunCommand(Connection.Ref, "FinishProcessingEvents", InputParameters, Output_Parameters);
				
			EndIf;
			
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Processes the event data received from the client.
//
Function ProcessEventFromDevice(DetailsEvents, ErrorDescription = "") Export

	Result = True;
	
	// Searching for an event handler
	For Each Connection IN glPeripherals.PeripheralsConnectingParameters Do
						  
		If Connection.EventSource = DetailsEvents.Source
		 Or (IsBlankString(Connection.EventSource)
		   AND Connection.NamesEvents <> Undefined) Then
		   
		   // Look for device with the enabled event among the peripherals.
			Event = Connection.NamesEvents.Find(DetailsEvents.Event);
			If Event <> Undefined Then
				
				DriverHandler = EquipmentManagerClientReUse.GetDriverHandler(Connection.DriverHandler, Not Connection.AsConfigurationPart);
				If DriverHandler = PeripheralsUniversalDriverClientAsynchronously 
					Or DriverHandler = PeripheralsUniversalDriverClient Then
					
					Output_Parameters = New Array();
					// Processing a message
					Result = DriverHandler.ProcessEvent(Undefined, Connection.Parameters, Connection.ConnectionParameters, DetailsEvents.Event, DetailsEvents.Data, Output_Parameters);
					// Processing a message
					If Result Then
						// Notify 
						Notify(Output_Parameters[0], Output_Parameters[1], "Peripherals");
					EndIf;
					
				Else
					
					InputParameters  = New Array();
					InputParameters.Add(DetailsEvents.Event);
					InputParameters.Add(DetailsEvents.Data);
					Output_Parameters = Undefined;
					// Processing a message
					Result = RunCommand(Connection.Ref, "ProcessEvent", InputParameters, Output_Parameters);
					If Result Then
						// Notify 
						Notify(Output_Parameters[0], Output_Parameters[1], "Peripherals");
					EndIf;
				    // Notify driver on event processor end.
					InputParameters.Clear();
					InputParameters.Add(Result);
					RunCommand(Connection.Ref, "FinishProcessingEvents", InputParameters, Output_Parameters);
				EndIf;
			EndIf;
			
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region CommonCommandsProcedures

// Open form of work places list.
//
Procedure OpenWorkplaces(CommandParameter, CommandExecuteParameters) Export
	
	EquipmentManagerClient.RefreshClientWorkplace();
	FormParameters = New Structure();
	OpenForm("Catalog.Workplaces.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

// Procedure for work place selection of the current session.
//
Procedure ChooseWSCurrentSession(CommandParameter, CommandExecuteParameters) Export
	
	Notification = New NotifyDescription("OfferWorkplaceSelectionEnd", ThisObject);
	EquipmentManagerClient.OfferWorkplaceSelection(Notification);
	
EndProcedure

// Open peripherals form.
//
Procedure OpenPeripherals(CommandParameter, CommandExecuteParameters) Export
	
	EquipmentManagerClient.RefreshClientWorkplace();
	
	FormParameters = New Structure();
	OpenForm("Catalog.Peripherals.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

// Open equipment drivers form.
//
Procedure OpenHardwareDrivers(CommandParameter, CommandExecuteParameters) Export
	
	EquipmentManagerClient.RefreshClientWorkplace();
	
	FormParameters = New Structure();
	OpenForm("Catalog.HardwareDrivers.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region WorkWithDriverProceduresAndFunctions

// Checks if driver is set.
//
Function DriverIsSet(ID) Export
	
	EquipmentData = EquipmentManagerServerCall.GetDeviceData(ID);
	DriverObject = GetDriverObject(EquipmentData);
	
	Return DriverObject <> Undefined;
	
EndFunction

#If Not WebClient Then

// Install or reinstall selected drivers.
//
Procedure ResetMarkedDrivers() Export
	
	SystemInfo = New SystemInfo();
	WorkplacesArray = EquipmentManagerClientReUse.FindWorkplacesById(Upper(SystemInfo.ClientID));
	If WorkplacesArray.Count() = 0 Then
		Workplace = Undefined
	Else
		Workplace = WorkplacesArray[0];
	EndIf;
	
	// Reset drivers marked with check box for resetting.
	If ValueIsFilled(Workplace) Then
		EquipmentList = EquipmentManagerServerCall.GetDriversListForReinstallation(Workplace);
		For Each Equipment IN EquipmentList Do
			If Equipment.DriverData.AsConfigurationPart AND Not Equipment.DriverData.SuppliedAsDistribution Then
				BeginInstallAddIn(, "CommonTemplate." + Equipment.DriverData.DriverTemplateName);
			EndIf;
			EquipmentManagerServerCall.SetReinstallSignDrivers(Workplace, Equipment.HardwareDriver, False); 
		EndDo;
	EndIf;
	
	// Install drivers marked to be installed.
	If ValueIsFilled(Workplace) Then
		EquipmentList = EquipmentManagerServerCall.GetDriversListForInstallation(Workplace);
		For Each Equipment IN EquipmentList Do
			If Equipment.DriverData.AsConfigurationPart AND Not Equipment.DriverData.SuppliedAsDistribution Then
				DriverObject = GetDriverObject(Equipment.DriverData);
				If DriverObject = Undefined Then
					BeginInstallAddIn(, "CommonTemplate." + Equipment.DriverData.DriverTemplateName);
				Else
					DisconnectDriverObject(Equipment.DriverData);
				EndIf;
			EndIf;
			EquipmentManagerServerCall.SetSignOfDriverInstallation(Workplace, Equipment.HardwareDriver, False); 
		EndDo;
	EndIf;
	
EndProcedure

Procedure StartDriverSettingFromDistributionEnd(Result, Parameters) Export
	
	If Parameters.Property("TempFile") Then
		BeginDeletingFiles(, Parameters.TempFile);
	EndIf;
	If Parameters.Property("InstallationDirectory") Then
		BeginDeletingFiles(, Parameters.InstallationDirectory);
	EndIf;
	
	If Parameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(Parameters.AlertOnEnd, Result = 0);
	EndIf;
	
EndProcedure

// Start the driver installation from the supplier distribution from template.
//
Procedure StartDriverSettingFromDistributionInLayout(AlertOnEnd, TemplateName, FileName) Export
	
	Result = False;
	// Getting a template from the server
	FileReference = EquipmentManagerServerCall.GetTemplateFromServer(TemplateName);
	FileNameTemp = ?(IsBlankString(FileName), "setup.exe", FileName);
	
	// StartGetTemporaryFilesDirectory 
	TemporaryDirectory   = TempFilesDir();
	TempFile      = TemporaryDirectory + "Model.zip";
	InstallationDirectory = TemporaryDirectory + "Model\";
	
	// Unpack the distribution archive into a temporary directory.
	Result = GetFile(FileReference, TempFile, False);
	
	FileOfArchive = New ZipFileReader();
	FileOfArchive.Open(TempFile);
	
	If FileOfArchive.Items.Find(FileNameTemp) <> Undefined Then
		// Unpack distribution
		FileOfArchive.ExtractAll(InstallationDirectory);
		FileOfArchive.Close();
		// Run installation
		Parameters = New Structure("InstallationDirectory, TempFile, AlertOnEnd", InstallationDirectory, TempFile, AlertOnEnd);
		Notification = New NotifyDescription("StartDriverSettingFromDistributionEnd", ThisObject, Parameters);
		BeginRunningApplication(Notification, InstallationDirectory + FileNameTemp, InstallationDirectory, True);
	Else
		ErrorText = NStr("en='An error occurred while setting driver from distributive in template.
		|File %File% is not found in template.';ru='Ошибка установки драйвера из дистрибутива в макете.
		|Файл ""%Файл%"" в макете не найден.'");
		ErrorText = StrReplace(ErrorText, "%File%", FileNameTemp);
		CommonUseClientServer.MessageToUser(ErrorText); 
		BeginDeletingFiles(, TempFile);
		If AlertOnEnd <> Undefined Then
			ExecuteNotifyProcessing(AlertOnEnd, False);
		EndIf;
	EndIf;
	
EndProcedure

Procedure StartDriverSettingFromDistributionFromBaseEnd(Result, Parameters) Export
	
	BeginDeletingFiles(, Parameters.TemporaryDirectory + "Model\");
	BeginDeletingFiles(, Parameters.TemporaryDirectory + "Model.zip");
	
	If Parameters.AlertOnEnd <> Undefined Then
		ExecuteNotifyProcessing(Parameters.AlertOnEnd, Result = 0);
	EndIf;
	
EndProcedure

// Start setting driver from distributive of vendor from base.
//
Procedure StartDriverSettingFromBaseDistribution(AlertOnEnd, DriverData) Export
	
	Result = False;
	
	TemporaryDirectory   = TempFilesDir();
	FileNameTemp       = TemporaryDirectory + DriverData.DriverFileName;
	InstallationDirectory = TemporaryDirectory + "Model\";
	
	GetFile(GetURL(DriverData.HardwareDriver, "ExportedDriver"), FileNameTemp, False);
	TempFile = New File(FileNameTemp);
	
	If Upper(TempFile.Extension) = ".ZIP" Then
		// Unpack distribution
		FileOfArchive = New ZipFileReader();
		FileOfArchive.Open(TempFile.DescriptionFull);
		
		InstalledFileName = "";
		If FileOfArchive.Items.Find(TempFile.BaseName  + ".EXE") <> Undefined Then
			InstalledFileName = TempFile.BaseName  + ".EXE";
		ElsIf FileOfArchive.Items.Find("setup.exe") <> Undefined Then
			InstalledFileName = "setup.exe";
		EndIf;
		
		If Not IsBlankString(InstalledFileName) Then
			// Unpack distribution
			FileOfArchive.ExtractAll(InstallationDirectory);
			FileOfArchive.Close();
			// Run installation
			Parameters = New Structure("InstallationDirectory, TempFile, AlertOnEnd", InstallationDirectory, FileNameTemp, AlertOnEnd);
			Notification = New NotifyDescription("StartDriverSettingFromDistributionEnd", ThisObject, Parameters);
			BeginRunningApplication(Notification, InstallationDirectory + InstalledFileName, InstallationDirectory, True);
		Else
			FileOfArchive.Close();
			ErrorText = NStr("en='An error occurred while setting driver from distributive in archive.
		|Required file is not found in archive.';ru='Ошибка установки драйвера из дистрибутива в архиве.
		|Необходимый файл в архиве не найден.'");
			CommonUseClientServer.MessageToUser(ErrorText); 
			BeginDeletingFiles(, FileNameTemp);
		EndIf;
	Else
		// Run installation
		Parameters = New Structure("TempFile, AlertOnEnd", FileNameTemp, AlertOnEnd);
		Notification = New NotifyDescription("StartDriverSettingFromDistributionEnd", ThisObject, Parameters);
		BeginRunningApplication(Notification, TemporaryDirectory + FileNameTemp, TemporaryDirectory, True);
	EndIf;
	
EndProcedure

#EndIf

// Disconnecting a driver object.
//
Procedure DisconnectDriverObject(DriverData) Export

	ArrayLineNumber = glPeripherals.PeripheralsConnectingParameters.Find(DriverData.HardwareDriver);
	If ArrayLineNumber <> Undefined Then
		glPeripherals.PeripheralsConnectingParameters.Delete(ArrayLineNumber);
	EndIf;
	
EndProcedure

// Getting a driver object
//
Function GetDriverObject(DriverData, ErrorText = Undefined) Export
	
	DriverObject = Undefined;
	
	For Each Driver IN glPeripherals.PeripheralsDrivers Do
		If Driver.Key = DriverData.HardwareDriver  Then
			DriverObject = Driver.Value;
			Break;
		EndIf;
	EndDo;   
	
	If DriverObject = Undefined Then
		Try
			
			ProgID = DriverData.ObjectID;
			If IsBlankString(ProgID) Then
				DriverObject = ""; // Driver is not required
			Else
				ProgID1 = ?(Find(ProgID, "|") > 0, Mid(ProgID, 1, Find(ProgID, "|")-1), ProgID); 
				ProgID2 = ?(Find(ProgID, "|") > 0, Mid(ProgID, Find(ProgID, "|")+1), ProgID); 
				If DriverData.SuppliedAsDistribution Then
					AttachAddIn(ProgID1);
				Else
					ObjectName = Mid(ProgID1, Find(ProgID1, ".") + 1); 
					Prefix = Mid(ProgID1, 1, Find(ProgID1, ".")); 
					ProgID2 = Prefix + StrReplace(ObjectName, ".", "_") + "." + ObjectName;
					If DriverData.AsConfigurationPart Then
						Result = AttachAddIn("CommonTemplate." + DriverData.DriverTemplateName, StrReplace(ObjectName, ".", "_"));
					Else
						DriverLink = GetURL(DriverData.HardwareDriver, "ExportedDriver");
						Result = AttachAddIn(DriverLink, StrReplace(ObjectName, ".", "_"));
					EndIf;
				EndIf;
				DriverObject = New (ProgID2);
				
			EndIf;
				
		Except
			Info = ErrorInfo();
			ErrorText = Info.Description;
		EndTry;
		
		If DriverObject <> Undefined Then
			glPeripherals.PeripheralsDrivers.Insert(DriverData.HardwareDriver, DriverObject);
			DriverObject = glPeripherals.PeripheralsDrivers[DriverData.HardwareDriver];
		EndIf;
		
	EndIf;   
		
	Return DriverObject;
	
EndFunction

Procedure StartReceiveDriverObjectEnd(Attached, AdditionalParameters) Export
	
	DriverObject = Undefined;
	
	If Attached Then 
		Try
			DriverObject = New (AdditionalParameters.ProgID);
			If DriverObject <> Undefined Then
				glPeripherals.PeripheralsDrivers.Insert(AdditionalParameters.HardwareDriver, DriverObject);
				DriverObject = glPeripherals.PeripheralsDrivers[AdditionalParameters.HardwareDriver];
			EndIf;
			ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, DriverObject);
			Return;
		Except
		EndTry;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.AlertOnEnd, Undefined);
	
EndProcedure

// Start receiving driver object.
//
Procedure StartReceivingDriverObject(AlertOnEnd, DriverData) Export
	
	DriverObject = Undefined;
	
	For Each Driver IN glPeripherals.PeripheralsDrivers Do
		If Driver.Key = DriverData.HardwareDriver  Then
			DriverObject = Driver.Value;
			ExecuteNotifyProcessing(AlertOnEnd, DriverObject);
			Return;
		EndIf;
	EndDo;   
	
	If DriverObject = Undefined Then
			ProgID = DriverData.ObjectID;
			If IsBlankString(ProgID) Then
				DriverObject = ""; // Driver is not required
				ExecuteNotifyProcessing(AlertOnEnd, DriverObject);
			Else
				ProgID1 = ?(Find(ProgID, "|") > 0, Mid(ProgID, 1, Find(ProgID, "|")-1), ProgID); 
				ProgID2 = ?(Find(ProgID, "|") > 0, Mid(ProgID, Find(ProgID, "|")+1), ProgID); 
				
				If DriverData.SuppliedAsDistribution Then
					Parameters = New Structure("ProgID, AlertOnEnd, HardwareDriver", ProgID2, AlertOnEnd, DriverData.HardwareDriver);
					Notification = New NotifyDescription("StartReceiveDriverObjectEnd", ThisObject, Parameters);
					BeginAttachingAddIn(Notification, ProgID1);
				Else
					ObjectName = Mid(ProgID1, Find(ProgID1, ".") + 1); 
					Prefix = Mid(ProgID1, 1, Find(ProgID1, ".")); 
					ProgID2 = Prefix + StrReplace(ObjectName, ".", "_") + "." + ObjectName;
					
					Parameters = New Structure("ProgID, AlertOnEnd, HardwareDriver", ProgID2, AlertOnEnd, DriverData.HardwareDriver);
					Notification = New NotifyDescription("StartReceiveDriverObjectEnd", ThisObject, Parameters);
					If DriverData.AsConfigurationPart Then
						BeginAttachingAddIn(Notification, "CommonTemplate." + DriverData.DriverTemplateName, StrReplace(ObjectName, ".", "_"));
					Else
						DriverLink = GetURL(DriverData.HardwareDriver, "ExportedDriver");
						BeginAttachingAddIn(Notification, DriverLink, StrReplace(ObjectName, ".", "_"));
					EndIf;
				EndIf;
				
			EndIf;
	EndIf;   
	
EndProcedure

// Set equipment driver.
//
Procedure SetupDriver(ID, AlertFromDistributionOnEnd = Undefined, AlertFromArchiveOnEnd = Undefined) Export
	
	DriverData = EquipmentManagerServerCall.GetDriverData(ID);
	
	Try  
		If DriverData.AsConfigurationPart Then
			
			If DriverData.SuppliedAsDistribution Then
			#If WebClient Then
				CommonUseClientServer.MessageToUser(NStr("en='This driver does not support work in web client.';ru='Данный драйвер не поддерживает работу в веб-клиенте.'")); 
			#Else
				If EquipmentManagerClientReUse.IsLinuxClient() Then
					CommonUseClientServer.MessageToUser(NStr("en='The driver can not be installed and used in the Linux environment.';ru='Данный драйвер не может быть установлен и использован в среде Linux.'")); 
					Return;
				EndIf;
				StartDriverSettingFromDistributionInLayout(AlertFromDistributionOnEnd, DriverData.DriverTemplateName, DriverData.DriverFileName);
			#EndIf
			Else
				BeginInstallAddIn(AlertFromArchiveOnEnd, "CommonTemplate." + DriverData.DriverTemplateName);
			EndIf;
			
		Else
			
			If DriverData.SuppliedAsDistribution Then
			#If WebClient Then
				CommonUseClientServer.MessageToUser(NStr("en='This driver does not support work in web client.';ru='Данный драйвер не поддерживает работу в веб-клиенте.'")); 
			#Else
				If EquipmentManagerClientReUse.IsLinuxClient() Then
					CommonUseClientServer.MessageToUser(NStr("en='The driver can not be installed and used in the Linux environment.';ru='Данный драйвер не может быть установлен и использован в среде Linux.'")); 
					Return;
				EndIf;
				StartDriverSettingFromBaseDistribution(AlertFromDistributionOnEnd, DriverData);
			#EndIf
			Else
				DriverLink = GetURL(DriverData.HardwareDriver, "ExportedDriver");
				BeginInstallAddIn(AlertFromArchiveOnEnd, DriverLink);
			EndIf;
			
		EndIf;
		
	Except
		CommonUseClientServer.MessageToUser(NStr("en='An error occurred while setting driver.';ru='Произошла ошибка при установке драйвера.'")); 
	EndTry;  
		
EndProcedure

#EndRegion