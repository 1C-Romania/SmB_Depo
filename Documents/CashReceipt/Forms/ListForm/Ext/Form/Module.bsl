#Region EventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	If Parameters.Property("CashIncomeOfRetailRevenue") Then
		
		ValueList = New ValueList;
		ValueList.Add(Enums.OperationKindsCashReceipt.RetailIncome);
		ValueList.Add(Enums.OperationKindsCashReceipt.RetailIncomeAccrualAccounting);
		
		SmallBusinessClientServer.SetListFilterItem(List,"OperationKind",ValueList,True,DataCompositionComparisonType.InList);
		
		ThisForm.AutoTitle = False;
		ThisForm.Title = "Cash receipt of retail revenue";
	
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
EndProcedure 

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany 		= Settings.Get("FilterCompany");
	PettyCashFilter 				= Settings.Get("PettyCashFilter");
	FilterTypeOperations 		= Settings.Get("FilterTypeOperations"); 
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	SmallBusinessClientServer.SetListFilterItem(List, "PettyCash", PettyCashFilter, ValueIsFilled(PettyCashFilter));
	SmallBusinessClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
Procedure FilterCompanyOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
Procedure FilterPettyCashOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "PettyCash", PettyCashFilter, ValueIsFilled(PettyCashFilter));
EndProcedure

&AtClient
Procedure FilterOperationKindOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "OperationKind", FilterTypeOperations, ValueIsFilled(FilterTypeOperations));
EndProcedure

#EndRegion

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingCashReceipt";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningCashReceipt";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// ServiceTechnology.InformationCenter
&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure
// End ServiceTechnology.InformationCenter

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
