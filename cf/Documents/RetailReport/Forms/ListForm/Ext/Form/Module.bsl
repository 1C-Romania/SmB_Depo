
///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.CommandListGroup);
	// End StandardSubsystems.Printing
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(RetailSalesReports);
	
EndProcedure // OnCreateAtServer()

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	CashCR = Settings.Get("CashCR");
	SetDynamicListsFilter();
	
EndProcedure // OnLoadDataFromSettingsAtServer()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM FIELD EVENT HANDLERS

&AtClient
Procedure SetEnabledOfCreateNewDocumentButtons()
	
	CashCRFilled = ValueIsFilled(CashCR);
	
	Items.ReportsAboutRetailSalesCreate.Enabled                    = Not CashFiscalRegister AND CashCRFilled;
	Items.ReportsAboutRetailSalesCopy.Enabled                = Not CashFiscalRegister AND CashCRFilled;
	Items.ContextMenuRetailSalesReportsCreate.Enabled     = Not CashFiscalRegister AND CashCRFilled;
	Items.ContextMenuRetailSalesReportsCopy.Enabled = Not CashFiscalRegister AND CashCRFilled;
	
EndProcedure // SetEnabledOfCreateNewDocumentButtons()

// Procedure sets filter of dynamic form lists.
//
&AtServer
Procedure SetDynamicListsFilter()
	
	SmallBusinessClientServer.SetListFilterItem(RetailSalesReports, "CashCR", CashCR, ValueIsFilled(CashCR), DataCompositionComparisonType.Equal);
	SmallBusinessClientServer.SetListFilterItem(RetailSalesReports, "CashCRSessionStatus", CashCRSessionStatus, ValueIsFilled(CashCRSessionStatus), DataCompositionComparisonType.Equal);
	
EndProcedure // SetDynamicListsFilter()

// Procedure - event handler "OnChange" of field "CashCR".
//
&AtServer
Procedure PettyCashFilterOnChangeAtServer()
	
	SetDynamicListsFilter();
	CashFiscalRegister = Catalogs.CashRegisters.GetCashRegisterAttributes(CashCR).CashCRType = Enums.CashCRTypes.FiscalRegister;
	
EndProcedure // PettyCashFilterOnChangeAtServer()

// Procedure - event handler "OnChange" of field "CashRegister" at server.
//
&AtClient
Procedure PettyCashFilterOnChange(Item)
	
	PettyCashFilterOnChangeAtServer();
	SetEnabledOfCreateNewDocumentButtons();
	
EndProcedure // PettyCashFilterOnChange()

// Procedure - event handler "OnChange" of field "CashRegister" at server.
//
&AtClient
Procedure CashCRSessionStatusFilterOnChange(Item)
	
	SetDynamicListsFilter();
	
EndProcedure // CashCRSessionStatusFilterOnChange()

&AtClient
// Procedure - form event handler "NotificationProcessing".
//
Procedure NotificationProcessing(EventName, Parameter, Source)

	If EventName  = "RefreshFormsAfterZReportIsDone" Then
		Items.RetailSalesReports.Refresh();
	ElsIf EventName = "RefreshFormsAfterClosingCashCRSession" Then
		Items.RetailSalesReports.Refresh();
	EndIf;

EndProcedure // NotificationProcessing()

// Procedure - form event handler "OnOpen".
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetEnabledOfCreateNewDocumentButtons();

EndProcedure // OnOpen()

// Procedure - command handler "OpenFiscalRegisterManagement".
//
&AtClient
Procedure OpenFiscalRegisterManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.FiscalRegisterManagement");

EndProcedure // OpenFiscalRegisterManagement)(

// Procedure - command handler "OpenPOSTerminalManagement".
//
&AtClient
Procedure OpenPOSTerminalManagement(Command)
	
	OpenForm("Catalog.Peripherals.Form.POSTerminalManagement");

EndProcedure // OpenPOSTerminalManagement()

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.RetailSalesReports);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion













