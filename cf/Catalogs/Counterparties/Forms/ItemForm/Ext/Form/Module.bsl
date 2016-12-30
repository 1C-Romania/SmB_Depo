#Region ModuleVariables

&AtServer
Var CreateSupplierPriceKind; // It is created for all new counterparties starting from 1.4.3 version

&AtClient
Var CIData;

#EndRegion

#Region CommonUseProceduresAndFunctions

// Function returns a parameter structure for
// a new item of the Counterparty Price Kind catalog
//
&AtServer
Function NewElementTypeOptionsPricingCounterparty()
	
	Return New Structure("Description, Owner, PriceCurrency, PriceIncludesVAT, Comment", 
		Left("Prices for " + Object.Description, 25),
		Object.Ref,
		Constants.NationalCurrency.Get(),
		True,
		"Registers the incoming prices. Is automatically created.");
	 
EndFunction // NewCounterpartyPriceKindItemParameters()

// Procedure creates the supplier price kind and fills in the corresponding attribute.
// It is running on the server after recording a new item of the Counterparty catalog.
//
&AtServer
Procedure CreateViewPricesProvider()
	
	SetPrivilegedMode(True);
	
	CounterpartyPriceKind = FindCounterpartyPricesKind();
	
	If Not ValueIsFilled(CounterpartyPriceKind) Then
	
		CounterpartyPriceKind = Catalogs.CounterpartyPriceKind.CreateItem();
		FillPropertyValues(CounterpartyPriceKind, NewElementTypeOptionsPricingCounterparty());
		CounterpartyPriceKind.Write();
		
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure // CreateSupplierPriceKind()

// The function determines if at least one kind of the supplier price is entered for the current counterparty
// 
&AtServer
Function FindCounterpartyPricesKind()
	
	SetPrivilegedMode(True);
	
	Query = New Query("Select * From Catalog.CounterpartyPriceKind AS CPK WHERE CPK.Owner = &Owner");
	Query.SetParameter("Owner", Object.Ref);
	
	QueryExecutionResult =  Query.Execute();
	
	If QueryExecutionResult.IsEmpty() Then
		
		Return Undefined;
		
	Else
		
		Selection = QueryExecutionResult.Select();
		Selection.Next();
		
		Return Selection.Ref;
		
	EndIf;
	
	SetPrivilegedMode(False);
	
EndFunction // SupplierPriceKindIsEntered()

// It receives email addresses by the passed reference.
//
&AtServerNoContext
Function GetEmailCounterparty(RefToCurrentItem)
	
	If RefToCurrentItem = Catalogs.Counterparties.EmptyRef() Then
		
		Return Undefined;
		
	EndIf;
	
	Result = New Array;
	MailAddressArray = New Array;
	StructureRecipient = New Structure("Presentation, Address", RefToCurrentItem);
	
	Query = New Query;
	Query.SetParameter("Ref", RefToCurrentItem);
	
	Query.Text =
	"SELECT
	|	CounterpartiesContactInformation.Ref.Description AS ContactPresentation,
	|	CounterpartiesContactInformation.EMail_Address AS EMail_Address,
	|	1 AS Order
	|FROM
	|	Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
	|WHERE
	|	CounterpartiesContactInformation.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	ContactPersonsContactInformation.Ref.Description,
	|	ContactPersonsContactInformation.EMail_Address,
	|	2
	|FROM
	|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
	|WHERE
	|	ContactPersonsContactInformation.Ref.Owner = &Ref
	|
	|ORDER BY
	|	Order";
	
	SelectionFromQuery = Query.Execute().Select();
	AddCounterpartyEmailAddress = True;
	While SelectionFromQuery.Next() Do
		
		If Not ValueIsFilled(SelectionFromQuery.EMail_Address)
			OR (SelectionFromQuery.Order = 2 AND Not AddCounterpartyEmailAddress) Then
			
			Continue;
			
		EndIf;
		
		If MailAddressArray.Find(SelectionFromQuery.EMail_Address) = Undefined Then
			
			MailAddressArray.Add(SelectionFromQuery.EMail_Address);
			AddCounterpartyEmailAddress = False;
			
		EndIf;
		
	EndDo;
	
	StructureRecipient.Address = StringFunctionsClientServer.GetStringFromSubstringArray(MailAddressArray, "; ");
	Result.Add(StructureRecipient);
	
	Return Result;
	
EndFunction //GetEMAILCounterparty()

// Sets the corresponding value for the GenerateDescriptionFullAutomatically variable.
//
&AtClientAtServerNoContext
Function SetFlagToFormDescriptionFullAutomatically(Description, DescriptionFull)
	
	Return (Description = DescriptionFull OR IsBlankString(DescriptionFull));
	
EndFunction // SetFlagToFormFullDescriptionAutomatically()

&AtServer
Procedure CheckChangesPossibility(Cancel)
	
	If DoOperationsByContracts = Object.DoOperationsByContracts
	   AND DoOperationsByDocuments = Object.DoOperationsByDocuments
	   AND DoOperationsByOrders = Object.DoOperationsByOrders Then
		Return;
	EndIf;
	
	Query = New Query;
	
	QueryText =
	"SELECT
	|	AccountsReceivable.Counterparty
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Counterparty = &Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayable.Counterparty
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Counterparty = &Counterparty";
	
	Query.Text = QueryText;
	Query.SetParameter("Counterparty", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		MessageText = NStr("en='There are register records of settlements with the counterparty in the base. Changing the analytics of settlements accounting is prohibited.';ru='В базе присутствуют движения по взаиморасчетам с контрагентом. Изменение аналитики учета взаиморасчетов запрещено.'");
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText, , , , Cancel);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object = Form.Object;
	
	If Object.LegalEntityIndividual = Form.LegalEntity Then
		Items.PagesGroup.CurrentPage = Items.IndividualGroupUnavailable;
		Items.PagesTINAndKPP.CurrentPage = Items.PageCodesLegalEntities;
	Else
		If Not ValueIsFilled(Object.Individual) AND ValueIsFilled(Form.ViewIndividuals) Then
			Items.PagesGroup.CurrentPage = Items.GroupIndPresentation;
		Else
			Items.PagesGroup.CurrentPage = Items.GroupIndividualAvailable;
		EndIf;
		Items.PagesTINAndKPP.CurrentPage = Items.PageCodesIndividuals;
	EndIf;
	
	If Not ValueIsFilled(Object.ContactPerson) AND ValueIsFilled(Form.PresentationOfContactPerson) Then
		Items.PagesContactPerson.CurrentPage = Items.PageContactPersonPresentation;
	Else
		Items.PagesContactPerson.CurrentPage = Items.PageContactPerson;
	EndIf;
	
EndProcedure

// Procedure of auxiliary form opening to compare duplicated counterparties.
// 
&AtClient
Procedure HandleDuplicateChoiceSituation(Item)
	
	TransferParameters = New Structure;
	
	TransferParameters.Insert("TIN", TrimAll(Object.TIN));
	TransferParameters.Insert("KPP", TrimAll(Object.KPP));
	TransferParameters.Insert("ThisIsLegalEntity", Object.LegalEntityIndividual = LegalEntity);
	TransferParameters.Insert("CloseOnOwnerClose", True);
	
	WhatToExecuteAfterClosure = New NotifyDescription("HandleDuplicatesListFormClosure", ThisForm);
	
	OpenForm("Catalog.Counterparties.Form.DuplicatesChoiceForm", 
				  TransferParameters, 
				  Item,
				  ,
				  ,
				  ,
				  WhatToExecuteAfterClosure,
				  FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServerNoContext
Procedure CreateNewInd(CurrentObject, IndData)
	
	Ind = Catalogs.Individuals.CreateItem();
	FillPropertyValues(Ind, IndData);
	
	Ind.Description = IndData.Surname 
		+ ?(ValueIsFilled(IndData.Name), " " + IndData.Name, "")
		+ ?(ValueIsFilled(IndData.Patronymic), " " + IndData.Patronymic, "");
	Ind.Write();
	
	CurrentObject.Individual = Ind.Ref;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "GroupContactInformation");
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	LegalEntity = Enums.LegalEntityIndividual.LegalEntity;
	ColorHighlightIncorrectValues = StyleColors.ErrorCounterpartyHighlightColor;
	DoOperationsByContracts = Object.DoOperationsByContracts;
	DoOperationsByDocuments = Object.DoOperationsByDocuments;
	DoOperationsByOrders = Object.DoOperationsByOrders;
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(
		Object.Description,
		Object.DescriptionFull
	);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		// Responsible manager.
		User = Users.CurrentUser();
		Object.Responsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
		
		If Not IsBlankString(Parameters.FillingText) Then
			
			If (StrLen(Parameters.FillingText) = 10 OR StrLen(Parameters.FillingText) = 12)
				AND StringFunctionsClientServer.OnlyNumbersInString(Parameters.FillingText) Then
				
				Object.Description = "";
				Object.TIN = Parameters.FillingText;
				Object.LegalEntityIndividual = ?(StrLen(Parameters.FillingText) = 10, Enums.LegalEntityIndividual.LegalEntity, Enums.LegalEntityIndividual.Ind);
				Parameters.FillingText = Undefined;
				
			ElsIf GenerateDescriptionFullAutomatically Then
				Object.DescriptionFull = Parameters.FillingText;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Items.ContractByDefault.ReadOnly = Not Object.DoOperationsByContracts;
	
	If Users.InfobaseUserWithFullAccess()
		OR (IsInRole("OutputToPrinterClipboardFile")
		AND EmailOperations.CheckSystemAccountAvailable()) Then
		
		SystemEmailAccount = EmailOperations.SystemAccount();
		
	Else
		
		Items.FormSendEmailToCounterparty.Visible = False;
		
	EndIf;
	
	FormManagement(ThisForm);
	
EndProcedure // OnCreateAtServer()

// Procedure-handler of OnClose event.
//
&AtClient
Procedure OnClose()
	
	If CounterpartyStateChanged Then
		SaveCounterpartyCheckResultServer();
	EndIf;
	
EndProcedure

// Procedure-handler of the NotificationProcessing event.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
	//  We found a new contract by default
	//  in the list of contracts We found a new contact
	//  person by default in the list of contact persons We imported counterparty data from XML (EDB)
	If Find("RereadContractByDefault, RereadContactPersonByDefault, DefaultBankAccountIsChanged, UpdateEDState", EventName) > 0 Then
		ThisForm.Read();
	EndIf;
	
	If EventName = "SettlementAccountsAreChanged" Then
		Object.GLAccountCustomerSettlements = Parameter.GLAccountCustomerSettlements;
		Object.CustomerAdvancesGLAccount = Parameter.CustomerAdvanceGLAccount;
		Object.GLAccountVendorSettlements = Parameter.GLAccountVendorSettlements;
		Object.VendorAdvancesGLAccount = Parameter.AdvanceGLAccountToSupplier; 
		Modified = True;
	EndIf;
	
EndProcedure // NotificationProcessing()

// Event handler procedure OnReadAtServer
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	UpdateTagsCloud();
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

// Rise { Bernavski N 2016-09-16
&AtServer
Function CheckUniquenessOfCounterparty()
		
	StructureSearch = New Structure("Code,Description",Undefined,"=");
	
	If ValueIsFilled(Object.DescriptionFull) Then
		StructureSearch.Insert("DescriptionFull", "=");	
	EndIf;
	
	If ValueIsFilled(Object.TIN) Then
		StructureSearch.Insert("TIN", "=");
	EndIf;
	
	If ValueIsFilled(Object.KPP) Then
		StructureSearch.Insert("KPP", "=");
	EndIf;
	
	FoundObjects = Catalogs.Counterparties.FindDuplicates(Object, StructureSearch);
	                                            
	Return FoundObjects;	 
	
EndFunction

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If Not ClosingResult = True Then 	
		NotifyWritingNew(ClosingResult);
		Modified = False;
		If ThisForm.IsOpen() And ClosingResult <> Undefined Then
			Close();
		EndIf;
	ElsIf ClosingResult = True Then 	
		CheckedOnDuplicates = True;
		Write();
	EndIf;
	
EndProcedure // OnCloseSelection()
// Rise } Bernavski N 2016-09-16

// BeforeRecord event handler procedure.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogCounterpartiesWrite");
	// End StandardSubsystems.PerformanceEstimation
	
	// Rise { Bernavski N 2016-09-16
	If Not Cancel And Not CheckedOnDuplicates And Object.Ref.IsEmpty() And ValueIsFilled(Object.Description)And SmallBusinessReUse.GetValueByDefaultUser(UsersClientServer.CurrentUser(),"SearchDuplicatesOfCounterpartyWithoutCheckingCorrectnessTINAndKPP") = True Then
		Try
			FoundObjects = CheckUniquenessOfCounterparty();
		Except             
			Cancel = True;
			Info = ErrorInfo();
			If Info.Cause <> Undefined Then
				ErrorDescription = Info.Cause.Description;
			Else
				ErrorDescription = Info.Description;
			EndIf;

			Raise(ErrorDescription);
		EndTry;	
		If FoundObjects.Count() > 0 Then      
			
			NotifyDescription 		= New NotifyDescription("OnCloseSelection", ThisObject);
			
			FormParameters = New Structure;
			FormParameters.Insert("FoundObjects", FoundObjects); 
			
			OpenForm("Catalog.Counterparties.Form.DuplicatesCheckOnWriteForm", FormParameters, ThisForm,,,,NotifyDescription,FormWindowOpeningMode.LockOwnerWindow); 
			Cancel = True;
			CheckedOnDuplicates = False;
		EndIf;
	EndIf;
	// Rise } Bernavski N 2016-09-16
	
EndProcedure //BeforeWrite()

// Procedure-handler of the BeforeWriteAtServer event.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CheckChangesPossibility(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	CreateSupplierPriceKind = CurrentObject.IsNew();
	
	// Save address with the check result to the memory in order to exclude additional server call
	CurrentObject.AdditionalProperties.Insert("StorageAddress", StorageAddress);
	
	// Specify the need to fill the contact person by data of the uniform state registers
	If ContactPersonData <> Undefined Then
		CurrentObject.AdditionalProperties.Insert("ContactPersonData", ContactPersonData);
	EndIf;
	
	// Create an individual based on the uniform state register data
	If CurrentObject.LegalEntityIndividual <> LegalEntity AND IndData <> Undefined Then
		CreateNewInd(CurrentObject, IndData);
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject, Cancel);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

// Procedure-handler  of the AfterWriteOnServer event.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CreateSupplierPriceKind Then
		
		CreateViewPricesProvider();
		
	EndIf;
	
	If CurrentObject.AdditionalProperties.Property("ContactPersonData")
		AND Not CurrentObject.Modified() Then
		
		ContactPersonData		 = Undefined;
		PresentationOfContactPerson = Undefined;
		FormManagement(ThisObject);
		
	EndIf;
	
	If CurrentObject.LegalEntityIndividual <> LegalEntity AND IndData <> Undefined Then
		
		IndData		 = Undefined;
		ViewIndividuals = Undefined;
		FormManagement(ThisObject);
		
	EndIf;
	
EndProcedure // AfterWriteOnServer()

// AfterRecording event handler procedure.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	CounterpartyStateChanged = False;
	
	Notify("AfterRecordingOfCounterparty", Object.Ref);
	
EndProcedure // AfterWrite()

// Procedure-handler of the FillCheckProcessingAtServer event.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.FillCheckProcessingAtServer(ThisForm, Object, Cancel);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

#EndRegion

#Region FormAttributesEventsHandlers

// OnChange event handler procedure of the Description input field.
//
&AtClient
Procedure DescriptionOnChange(Item)
	
	If GenerateDescriptionFullAutomatically Then
		Object.DescriptionFull = Object.Description;
	EndIf;

EndProcedure // DescriptionOnChange()

// Event handler procedure OnChange of input field LegalEntityIndividual.
//
&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	If Object.LegalEntityIndividual = LegalEntity Then
		Object.Individual = Undefined;
	EndIf;
	
	FormManagement(ThisForm);
	
EndProcedure // LegalEntityIndividualOnChange()

// Procedure - SelectionBegin event handler of the BankAccountByDefault field.
//
&AtClient
Procedure BankAccountByDefaultStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		StandardProcessing = False;
		
		MessageText = NStr("az='Məlumat kitabçasının elementi hələ yazılmamışdır.';en='Catalog item is not recorded yet';lv='Rokasgrāmatas elements vēl nav pierakstīts';ro='Catalog element nu este înregistrată încă';ru='Элемент справочника еще не записан.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure // BankAccountByDefaultStartChoice()

// Procedure - SelectionBegin event handler of the ContractByDefault field.
//
&AtClient
Procedure ContractByDefaultStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		StandardProcessing = False;
		
		MessageText = NStr("az='Məlumat kitabçasının elementi hələ yazılmamışdır.';en='Catalog item is not recorded yet';lv='Rokasgrāmatas elements vēl nav pierakstīts';ro='Catalog element nu este înregistrată încă';ru='Элемент справочника еще не записан.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure // ContractByDefaultSelectionStart()

// Procedure - OnChange event handler of the SettlePaymentsForContracts field.
//
&AtClient
Procedure DoSettlementsOnChanges(Item)
	
	Items.ContractByDefault.ReadOnly = Not Object.DoOperationsByContracts;
	
EndProcedure // ContractPaymentsSettlememntOnChanges()

// Procedure - OnChange event handler of the DescriptionFull attribute
//
&AtClient
Procedure DescriptionFullOnChange(Item)
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(Object.Description, Object.DescriptionFull);
	
EndProcedure // DescriptionFullOnChange()

// Procedure - Clear event handler of the ContractByDefault attribute
//
&AtClient
Procedure DefaultContractClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SendEmailToCounterparty(Command)
	
	ListOfEmailAddresses = GetEmailCounterparty(Object.Ref);
	
	If ListOfEmailAddresses = Undefined Then
		
		ListOfEmailAddresses = New ValueList;
		MessageText = NStr("en='Counterparty is not written. The list of emails will be empty.';ru='Контрагент не записан. Список электронных адресов будет пуст.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	SendingParameters = New Structure("Recipient, DeleteFilesAfterSend", ListOfEmailAddresses, True);
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToCounterparty()

#EndRegion

#Region Tags

&AtClient
Procedure TagOnChange(Item)
	
	ContactsClassificationClient.TagOnChange(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_TagURLProcessing(Item, URL, StandardProcessing)
	
	ContactsClassificationClient.TagURLProcessing(ThisForm, Item, URL, StandardProcessing);
	
EndProcedure

&AtServer
Procedure UpdateTagsCloud()
	
	ContactsClassification.UpdateTagsCloud(ThisForm);
	
EndProcedure

#EndRegion

#Region CheckFTSCounterparty

&AtClientAtServerNoContext
Function CounterpartiesCheckIsPossible(Form)
	
	If Not Form.UseChecksAllowed Then
		Return False;
	EndIf;
	
	Return True;

EndFunction

&AtServer
Procedure SaveCounterpartyCheckResultServer()
	
	CounterpartiesCheck.SaveCounterpartiesCheckResult(Object, StorageAddress);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.ContactInformation
&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	Result = ContactInformationManagementClient.PresentationStartChoice(ThisForm, Item, , StandardProcessing);
	
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	
	Result = ContactInformationManagementClient.ClearingPresentation(ThisForm, Item.Name);
	
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	Result = ContactInformationManagementClient.LinkCommand(ThisForm, Command.Name);
	
	RefreshContactInformation(Result);
	
	ContactInformationManagementClient.OpenAddressEntryForm(ThisForm, Result);
	
EndProcedure

&AtServer
Function RefreshContactInformation(Result = Undefined)
	
	Return ContactInformationManagement.RefreshContactInformation(ThisForm, Object, Result);
	
EndFunction
// End StandardSubsystems.ContactInformation

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

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

#EndRegion