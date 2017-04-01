#Region ProgramInterface

// Function exports the changes of products data in the equipment Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting 
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousExportProductsInEquipmentOffline(EquipmentType, DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation, ModifiedOnly = True) Export
	
	Status(NStr("en='Products are being exported to the equipment Offline...';ru='Выполняется выгрузка товаров в оборудование Offline...'"));
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier IN DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription = "";
		ClientID = New UUID;
		
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			StructureData = PeripheralsOfflineServerCall.GetDataForPettyCash(DeviceIdentifier, ModifiedOnly);
		Else
			StructureData = PeripheralsOfflineServerCall.GetDataForScales(DeviceIdentifier, ModifiedOnly);
		EndIf;
		
		If StructureData.Data.Count() = 0 Then
			Result = False;
			If StructureData.ExportedRowsWithErrorsCount = 0 Then
				ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(DeviceIdentifier, Undefined, ErrorsDescriptionFull, NStr("en='There is no data to export!';ru='Нет данных для выгрузки!'"));
			Else
				ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(DeviceIdentifier, Undefined, ErrorsDescriptionFull, StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Data is not exported. Errors detected: %1';ru='Данные не выгружены. Обнаружено ошибок: %1'"), StructureData.ExportedRowsWithErrorsCount));
			EndIf;
			Continue;
		EndIf;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ImportIntoEquipmentOfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, StructureData",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, StructureData 
			)
		);
		
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			EquipmentManagerClient.StartDataExportToCROffline(
				NotificationsOnCompletion, 
				ClientID,
				DeviceIdentifier,
				StructureData.Data,
				StructureData.PartialExport
			);
		Else
			EquipmentManagerClient.StartDataExportToScalesWithLabelsPrinting(
				NotificationsOnCompletion, 
				ClientID,
				DeviceIdentifier,
				StructureData.Data,
				StructureData.PartialExport
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Function clears the list of products in the equipment Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousClearProductsInEquipmentOffline(EquipmentType, DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation) Export
	
	Status(NStr("en='Products are being cleared in the Offline equipment...';ru='Выполняется очистка товаров в оборудовании Offline...'"));
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier IN DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription     = "";
		ClientID = New UUID;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ClearEquipmentBaseOfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation
			)
		);
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			EquipmentManagerClient.StartProductsCleaningInCROffline(
				NotificationsOnCompletion,
				ClientID,
				DeviceIdentifier
			);
		Else
			EquipmentManagerClient.StartClearingProductsInScalesWithLabelsPrinting(
				NotificationsOnCompletion,
				ClientID,
				DeviceIdentifier
			);
		EndIf;
	EndDo;
	
EndProcedure

// Function clears the list of products in the CR Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousImportReportAboutRetailSales(DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation) Export
	
	Status(NStr("en='Retail sales reports is being imported from the CR Offline...';ru='Выполняется загрузка отчетов о розничных продажах из ККМ Offline...'"));
	
	RetailSalesReports = New Array;
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier IN DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription  = "";
		ClientID = New UUID;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ImportReportCROfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, RetailSalesReports",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, RetailSalesReports
			)
		);
		EquipmentManagerClient.StartImportRetailSalesReportFromCROffline(
			NotificationsOnCompletion,
			ClientID,
			DeviceIdentifier
		);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

Procedure ImportIntoEquipmentOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Parameters.Completed = Parameters.Completed + 1;
	Else
		Parameters.ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(Parameters.DeviceIdentifier, Parameters.Output_Parameters, Parameters.ErrorsDescriptionFull, Parameters.ErrorDescription);
	EndIf;
	
	PeripheralsOfflineServerCall.OnProductsExportToDevice(Parameters.DeviceIdentifier, Parameters.StructureData, Result);
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousExportProductsInEquipmentOfflineFragment(Parameters);
	EndIf;
	
EndProcedure

Procedure ClearEquipmentBaseOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Parameters.Completed = Parameters.Completed + 1;
	Else
		Parameters.ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(Parameters.DeviceIdentifier, Parameters.Output_Parameters, Parameters.ErrorsDescriptionFull, Parameters.ErrorDescription);
	EndIf;
	
	PeripheralsOfflineServerCall.OnProductsClearingInDevice(Parameters.DeviceIdentifier, Result);
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousClearProductsInEquipmentOfflineFragment(Parameters);
	EndIf;

EndProcedure

Procedure ImportReportCROfflineEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array")
		AND Result.Count() > 0 Then
		RetailReport = PeripheralsOfflineServerCall.WhenImportingReportAboutRetailSales(Parameters.DeviceIdentifier, Result);
		If ValueIsFilled(RetailReport) Then
			EquipmentManagerClient.StartCheckBoxReportImportedCROffline(
				Parameters.ClientID,
				Parameters.DeviceIdentifier
			);
			Parameters.RetailSalesReports.Add(RetailReport);
			Parameters.Completed = Parameters.Completed + 1;
		EndIf;
	EndIf;
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousImportReportAboutRetailSalesFragment(Parameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GenerateErrorDescriptionForDevice(DeviceIdentifier, Output_Parameters, ErrorsDescriptionFull, ErrorDescription)
	
	Return ErrorsDescriptionFull
	      + Chars.LF
	      + StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Description of the errors for device %1: %2';ru='Описание ошибок для устройства %1: %2'"), DeviceIdentifier, ErrorDescription)
	      + ?(Output_Parameters <> Undefined, Chars.LF + Output_Parameters[1], "");
	
EndFunction

Procedure AsynchronousExportProductsInEquipmentOfflineFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en='The products have been sucessfully exported!';ru='Товары успешно выгружены!'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The products have been successfully exported for the %1 devices from %2.';ru='Товары успешно выгружены для %1 устройств из %2.'"), Parameters.Completed, Parameters.NeedToPerform) + Parameters.ErrorsDescriptionFull;
		Else
			MessageText = NStr("en='Failed to export the products:';ru='Выгрузить товары не удалось:'") + Parameters.ErrorsDescriptionFull;
		EndIf;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en='It is necessary to select the device for which the products should be exported.';ru='Необходимо выбрать устройство, для которого требуется выгрузить товары.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

Procedure AsynchronousClearProductsInEquipmentOfflineFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en='Products are successfully cleared!';ru='Товары успешно очищены!'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Products have been successfully cleared for %1 devices of %2. %3';ru='Товары успешно очищены для %1 устройств из %2. %3'"), Parameters.Completed, Parameters.NeedToPerform, Parameters.ErrorsDescriptionFull);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Failed to clear the products: %1';ru='Очистить товары не удалось: %1'"), Parameters.ErrorsDescriptionFull);
		EndIf;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en='It is necessary to select the device for which it is necessary to clear the products.';ru='Необходимо выбрать устройство, для которого требуется очистить товары.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

Procedure AsynchronousImportReportAboutRetailSalesFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en='The retail sales reports have been successfully imported!';ru='Отчеты о розничных продажах успешно загружены!'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The retail sales reports have been successfully imported for the %1 devices from %2.';ru='Успешно загружены отчеты о розничных продажах для %1 устройств из %2.'"), Parameters.Completed, Parameters.NeedToPerform) + Parameters.ErrorsDescriptionFull;
		Else
			MessageText = NStr("en='Failed to import the retail sales reports:';ru='Отчеты о розничных продажах загрузить не удалось:'") + Parameters.ErrorsDescriptionFull;
		EndIf;
		
		For Each RetailReport IN Parameters.RetailSalesReports Do
			OpenForm("Document.RetailReport.ObjectForm", New Structure("Key, PostOnOpen", RetailReport, True));
		EndDo;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en='It is necessary to select the device for which it is necessary to clear the products.';ru='Необходимо выбрать устройство, для которого требуется очистить товары.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

#EndRegion


