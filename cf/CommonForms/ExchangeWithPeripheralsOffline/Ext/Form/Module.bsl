
////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure AssignRuleForHighlitedDevicesAtServer(Device, ExchangeRule)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	
	For Each Device IN Device Do
		
		DeviceObject = Device.GetObject();
		DeviceObject.ExchangeRule = ExchangeRule;
		DeviceObject.Write();
		
	EndDo;
	
	CommitTransaction();
	
EndProcedure

&AtServer
Function GetReportAboutRetailSalesByPettyCash(CashCR, ImportDate)
	
	Report = Undefined;
	
	Query = New Query(
	"SELECT TOP 1
	|	RetailReport.Ref AS Report
	|FROM
	|	Document.RetailReport AS RetailReport
	|WHERE
	|	RetailReport.CashCR = &CashCR
	|	AND RetailReport.Date between &StartDate AND &EndDate");
	
	Query.SetParameter("CashCR", CashCR);
	Query.SetParameter("StartDate",    ImportDate - 5);
	Query.SetParameter("EndDate", ImportDate + 5);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Selection.Next() Then
		Report = Selection.Report;
	EndIf;
	
	Return Report;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	
	Scales.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
	CashRegisters.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	WarehouseCROffline = Settings.Get("WarehouseCROffline");
	WarehouseScales = Settings.Get("WarehouseScales");
	
	ExchangeRuleScales = Settings.Get("ExchangeRuleScales");
	CROfflineExchangeRule = Settings.Get("CROfflineExchangeRule");
	
	CommonUseClientServer.SetFilterItem(CashRegisters.Filter, "Warehouse", WarehouseCROffline, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseCROffline));
	CommonUseClientServer.SetFilterItem(CashRegisters.Filter, "ExchangeRule", CROfflineExchangeRule, DataCompositionComparisonType.Equal,, ValueIsFilled(CROfflineExchangeRule));
	CommonUseClientServer.SetFilterItem(Scales.Filter, "Warehouse", WarehouseScales, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseScales));
	CommonUseClientServer.SetFilterItem(Scales.Filter, "ExchangeRule", ExchangeRuleScales, DataCompositionComparisonType.Equal,, ValueIsFilled(ExchangeRuleScales));
	
	CommonUseClientServer.SetFilterItem(Scales.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentScales = False);
	CommonUseClientServer.SetFilterItem(CashRegisters.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentCROffline = False);
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CurrentSessionWorkplaceChanged" Then
		
		Workplace = EquipmentManagerServerCall.GetClientWorkplace();
		
		Scales.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
		CashRegisters.Parameters.SetParameterValue("CurrentWorksPlace", Workplace);
		
	ElsIf EventName = "Writing_ExchangeRulesWithPeripheralsOffline"
		OR EventName = "Record_CodesOfGoodsPeripheral" Then
		
		Items.Scales.Refresh();
		Items.CashRegisters.Refresh();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS

&AtClient
Procedure ScalesViewProductsList(Command)
	
	CurrentData = Items.Scales.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		FormParameters = New Structure("Device, ExchangeRule", CurrentData.Peripherals, CurrentData.ExchangeRule);
		OpenForm("InformationRegister.ProductsCodesPeripheralOffline.Form.ProductsList", FormParameters, UUID);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ScalesSetRuleForSelected(Command)
	
	Device = New Array;
	For Each SelectedRow IN Items.Scales.SelectedRows Do
		Device.Add(SelectedRow);
	EndDo;
	
	If Device.Count() > 0 Then
		
		OpenParameters = New Structure;
		OpenParameters.Insert("PeripheralsType", PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"));
		Notification = New NotifyDescription("ScalesSetRuleForSelectedCompletion",ThisForm,Device);
		OpenForm("Catalog.ExchangeWithPeripheralsOfflineRules.ChoiceForm", OpenParameters, UUID,,,,Notification);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ScalesSetRuleForSelectedCompletion(ExchangeRule,Device) Export
	
	If ValueIsFilled(ExchangeRule) Then
		AssignRuleForHighlitedDevicesAtServer(Device, ExchangeRule);
	EndIf;
		
	Items.Scales.Refresh();
	
EndProcedure

&AtClient
Procedure ScalesProductsExport(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"ScalesProductsExchangeScalesOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"), Items.Scales.SelectedRows,,, NotificationOnImplementation, True);
	
EndProcedure

&AtClient
Procedure ScalesProductsExchangeScalesOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Items.Scales.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure ScalesProductsClear(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"ScalesProductsExchangeScalesOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousClearProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"), Items.Scales.SelectedRows,,, NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure ScalesProductsReload(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"ScalesProductsExchangeScalesOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.LabelsPrintingScales"), Items.Scales.SelectedRows,,, NotificationOnImplementation, False);
	
EndProcedure

&AtClient
Procedure CashesViewProductList(Command)
	
	CurrentData = Items.CashRegisters.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		FormParameters = New Structure("Device, ExchangeRule", CurrentData.Peripherals, CurrentData.ExchangeRule);
		OpenForm("InformationRegister.ProductsCodesPeripheralOffline.Form.ProductsList", FormParameters, UUID);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PettyCashesSetRuleForSelected(Command)
	
	Device = New Array;
	For Each SelectedRow IN Items.CashRegisters.SelectedRows Do
		Device.Add(SelectedRow);
	EndDo;
	
	If Device.Count() > 0 Then
		
		OpenParameters = New Structure;
		OpenParameters.Insert("PeripheralsType", PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"));
		Notification = New NotifyDescription("PettyCashesSetRuleForSelectedCompletion",ThisForm,Device);
		OpenForm("Catalog.ExchangeWithPeripheralsOfflineRules.ChoiceForm", OpenParameters, UUID,,,,Notification);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PettyCashesSetRuleForSelectedCompletion(ExchangeRule,Device) Export
	
	If ValueIsFilled(ExchangeRule) Then
		AssignRuleForHighlitedDevicesAtServer(Device, ExchangeRule);
	EndIf;
		
	Items.CashRegisters.Refresh();
	
EndProcedure

&AtClient
Procedure PettyCashesProductsExport(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"PettyCashesProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"), Items.CashRegisters.SelectedRows,,, NotificationOnImplementation, True);
	
EndProcedure

&AtClient
Procedure PettyCashesProductsExchangeWithCashRegisterOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Items.CashRegisters.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure PettyCashesProductsClear(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"PettyCashesProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousClearProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"), Items.CashRegisters.SelectedRows,,, NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure PettyCashesProductsReload(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"PettyCashesProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline"), Items.CashRegisters.SelectedRows,,, NotificationOnImplementation, False);
	
EndProcedure

&AtClient
Procedure PettyCashesGoodsIImportReportAboutRetailSales(Command)
	
	NotificationOnImplementation = New NotifyDescription(
		"PettyCashesProductsExchangeWithCashRegisterOfflineEnd",
		ThisObject
	);
	
	PeripheralsOfflineClient.AsynchronousImportReportAboutRetailSales(Items.CashRegisters.SelectedRows,,, NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure ScalesOpenExchangeRule(Command)
	
	CurrentData = Items.Scales.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		ShowValue(Undefined,CurrentData.ExchangeRule);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PettyCashesOpenExchangeRule(Command)
	
	CurrentData = Items.CashRegisters.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.ExchangeRule) Then
		
		ShowValue(Undefined,CurrentData.ExchangeRule);
		
	Else
		
		ShowMessageBox(Undefined,NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AutomaticExchange(Command)
	
	FormParameters = New Structure("Workplace", Workplace);
	OpenForm("CommonForm.AutomaticExchangeWithPeripheralsOffline", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure WarehouseScalesOnChange(Item)
	
	CommonUseClientServer.SetFilterItem(Scales.Filter, "Warehouse", WarehouseScales, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseScales));
	
EndProcedure

&AtClient
Procedure ExchangeRuleScalesOnChange(Item)
	
	CommonUseClientServer.SetFilterItem(Scales.Filter, "ExchangeRule", ExchangeRuleScales, DataCompositionComparisonType.Equal,, ValueIsFilled(ExchangeRuleScales));
	
EndProcedure

&AtClient
Procedure WarehouseCashRegisterOfflineOnChange(Item)
	
	CommonUseClientServer.SetFilterItem(CashRegisters.Filter, "Warehouse", WarehouseCROffline, DataCompositionComparisonType.Equal,, ValueIsFilled(WarehouseCROffline));
	
EndProcedure

&AtClient
Procedure ExchangeRuleCashRegisterOfflineOnChange(Item)
	
	CommonUseClientServer.SetFilterItem(CashRegisters.Filter, "ExchangeRule", CROfflineExchangeRule, DataCompositionComparisonType.Equal,, ValueIsFilled(CROfflineExchangeRule));
	
EndProcedure

&AtClient
Procedure EquipmentCashRegisterOfflineOnChange(Item)
	
	CommonUseClientServer.SetFilterItem(CashRegisters.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentCROffline = False);
	
EndProcedure

&AtClient
Procedure EquipmentScalesOnChange(Item)
	
	CommonUseClientServer.SetFilterItem(Scales.Filter, "ConnectedToCurrentWorksplace", True, DataCompositionComparisonType.Equal,, AllEquipmentScales = False);
	
EndProcedure

&AtClient
Procedure CashRegistersChoice(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	
	If Field = Items.CashRegistersImportDate AND ValueIsFilled(CurrentData.ImportDate) Then
		StandardProcessing = False;
		Report = GetReportAboutRetailSalesByPettyCash(CurrentData.CashCR, CurrentData.ImportDate);
		
		If ValueIsFilled(Report) Then
			ShowValue(Undefined,Report);
		Else
			ShowMessageBox(Undefined,NStr("en='Retail sales report is not found.';ru='Отчет о розничных продажах не найден.'"));
		EndIf;
		
	EndIf;
	
EndProcedure
