
#Region FormVariables

&AtClient
Var SettingMainAccountCompleted; // Flag of successful setting of main bank account from a form of company / counterparty

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	If Parameters.Property("AutoTest") Then
		Return; // Return if the form for analysis is received..
	EndIf;
	
	Parameters.Filter.Property("Owner", AccountsOwner);
	
	If ValueIsFilled(AccountsOwner) Then
		// Context opening of the form with the selection by the counterparty / company
		
		AutoTitle = False;
		Title = NStr("ru='Банковские счета '; en='Bank accounts of '") + " """ + AccountsOwner + """";
		
		IsCounterparty = TypeOf(AccountsOwner) = Type("CatalogRef.Counterparties");
		
		Items.UseAsMain.Visible = AccessRight("Edit",
			?(IsCounterparty, Metadata.Catalogs.Counterparties, Metadata.Catalogs.Companies));
		
		List.Parameters.SetParameterValue("OwnerMainAccount",
			CommonUse.ObjectAttributeValue(AccountsOwner, "BankAccountByDefault"));
			
	Else
		// Opening in general mode
	
		Items.Owner.Visible = True;
		Items.UseAsMain.Visible = AccessRight("Edit", Metadata.Catalogs.Counterparties)
			And AccessRight("Edit", Metadata.Catalogs.Companies);
		
		List.Parameters.SetParameterValue("OwnerMainAccount", Undefined);
		
	КонецЕсли;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingMainAccountCompleted" Then
		SettingMainAccountCompleted = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow")
		And Items.List.CurrentData <> Undefined Then
		
		Items.UseAsMain.Enabled = Not Items.List.CurrentData.IsMainAccount;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UseAsMain(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMainAccount Then
		
		Return;
	EndIf;
	
	NewMainAccount = Items.List.CurrentData.Ref;
	
	// If the form of counterparty / organization is opened, then change the main account in it
	SettingMainAccountCompleted = False;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Owner", Items.List.CurrentData.Owner);
	ParametersStructure.Insert("NewMainAccount", NewMainAccount);
	
	Notify("SettingMainAccount", ParametersStructure, ThisObject);
	
	// If the form of counterparty / organization is closed, then change the main account by ourselves
	If Not SettingMainAccountCompleted Then
		WriteMainAccount(ParametersStructure);
	EndIf;
	
	// Update dynamical list
	If ValueIsFilled(AccountsOwner) Then
		List.Parameters.SetParameterValue("OwnerMainAccount", NewMainAccount);
	Else
		Items.List.Refresh();
	EndIf;
	
EndProcedure // UseAsMain()

#EndRegion

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingBankAccounts";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningBankAccounts";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServerNoContext
Procedure WriteMainAccount(ParametersStructure)
	
	OwnerObject = ParametersStructure.Owner.GetObject();
	OwnerSuccesfullyLocked = True;
	
	Try
		OwnerObject.Lock();
	Except
		
		OwnerSuccesfullyLocked = False;
		
		MessageText = NStr("en='Cannot lock object for changing the main bank account.';ru='Не удалось заблокировать объект для изменения основного банковского счета.'", Metadata.DefaultLanguage.LanguageCode);
		WriteLogEvent(MessageText, EventLogLevel.Warning,, OwnerObject, ErrorDescription());
		
	EndTry;
	
	// If lockig was successful edit bank account by default of counterparty / company
	If OwnerSuccesfullyLocked Then
		OwnerObject.BankAccountByDefault = ParametersStructure.NewBankAccount;
		OwnerObject.Write();
	EndIf;
	
EndProcedure

#EndRegion
