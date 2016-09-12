#Region ModuleVariables

&AtServer
Var CreateSupplierPriceKind; // It is created for all new counterparties starting from 1.4.3 version

&AtClient
Var CIData;

&AtClient
Var CheckResultInterval;

&AtClient
Var FillAttributesUsingTIN;

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

&AtServer
Procedure AddExtendedTooltipForFillingUsingTIN()
	
	// Check is always enabled in the service mode
	If CommonUseReUse.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	HasRightOnSettingsEditing = CounterpartiesCheck.HasRightOnSettingsEditing();
	HasRightOnCheckingUsage  = CounterpartiesCheck.HasRightOnCheckingUsage();
	CheckIsEnabled				  = CounterpartiesCheck.CounterpartiesCheckEnabled();
	
	If HasRightOnSettingsEditing Or HasRightOnCheckingUsage Then
		
		RowArray = New Array;
		RowArray.Add(Chars.LF);
		
		If CheckIsEnabled Then
			RowArray.Add(NStr("en='Check of the counterparties based on data is additionally enabled ';ru='Дополнительно включена проверка контрагентов по данным '"));
		Else
			RowArray.Add(NStr("en='You can additionally use the counterparty check based on data of ';ru='Дополнительно можно использовать проверку контрагентов по данным '"));
		EndIf;
		
		RowArray.Add(New FormattedString(NStr("az='FTS.';bg='FTS.';de='FTS.';en='FTS.';et='FTS.';ka='FTS.';lt='FTS.';lv='FTS.';mn='FTS.';pl='FTS.';ro='FTS.';ru='FTS.';sl='FTS.';tr='FTS.'"), New Font(,,True)));
		
		If HasRightOnSettingsEditing Then
			RowArray.Add(NStr("en='To configure the check it is necessary to go to ';ru='Для настройки проверки необходимо перейти в '"));
			RowArray.Add(New FormattedString(NStr("az='Kökləmələr - kontragentlərin yoxlamasının kökləməsidir.';en='Settings - Counterparty check settings.';lv='Konfigurācijas - Kontrahentu pārbaudes konfigurācijas.';ru='Настройки - Настройки проверки контрагентов.'")
				,,,,"CounterpartyVerificationsSetting"));
		ElsIf HasRightOnCheckingUsage AND Not CheckIsEnabled Then
			RowArray.Add(NStr("az='Yoxlamanın qurması kökləməsi üçün administratora müraciət edəcəksiniz.';en='To configure the check contact your administrator.';lv='Pārbaudes konfigurācijai vēršaties pie administratora';ru='Для настройки проверки обратитесь к администратору.'"));
		EndIf;
		
		Items.FillAttributesWithTIN.ExtendedTooltip.Title = New FormattedString(
			Items.FillAttributesWithTIN.ExtendedTooltip.Title, RowArray);
			
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

&AtClient
Procedure HandleDuplicatesListFormClosure(ClosingResult, AdditionalParameters) Export
	
	CheckDuplicates(ThisForm);
	
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
				
				FillAttributesUsingTINAtServer();
				
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
	
	Items.TIN.TypeRestriction = New TypeDescription("String", , New StringQualifiers(10));
	
	AddExtendedTooltipForFillingUsingTIN();
	
	FormManagement(ThisForm);
	
	CheckTIN = True;
	CheckKPP = True;
	
	StructureToCheckTINandKPP = StructureToCheckTINandKPP(ThisForm, CheckTIN, CheckKPP);
	
	ValidateTINandKPP(StructureToCheckTINandKPP, ThisForm);
	CheckDuplicates(ThisForm);
	
	// We received the check usage flag
	UseChecksAllowed = CounterpartiesCheckServerCall.UseChecksAllowed();
	
	// If the counterparty is not checked and the check is possible, we start the counterparty check
	If UseChecksAllowed Then
		
		CounterpartyState = CounterpartiesCheckServerCall.CurrentCounterpartyState(Object.Ref, Object.TIN, Object.KPP);
		StorageAddress 		 = CounterpartiesCheck.StorageAddressWithRestoredCounterpartyState(Object.Ref, Object.TIN, Object.KPP, UUID);
		
		If ValueIsFilled(CounterpartyState) Then
			DisplayCounterpartyCheckResult(ThisForm);
		Else
			CheckCounterparty(ThisForm);
		EndIf;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()

// Event handler procedure OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If Object.Ref.IsEmpty() Then
		If Object.LegalEntityIndividual = LegalEntity Then
			CurrentItem = Items.TIN;
		Else
			CurrentItem = Items.IndividualTIN;
		EndIf;
	EndIf;
	
	// If the counterparty state is not known, we are trying to define it
	If CounterpartiesCheckIsPossible(ThisForm) AND Not ValueIsFilled(CounterpartyState) Then
		CheckResultInterval = 1;
		AttachIdleHandler("Attachable_ProcessCounterpartyCheckResult", CheckResultInterval, True);
	EndIf;
	
EndProcedure

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

// BeforeRecord event handler procedure.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogCounterpartiesWrite");
	// End StandardSubsystems.PerformanceEstimation
	
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
		Object.TIN = Left(Object.TIN, 10);
		Object.Individual = Undefined;
	Else
		Object.KPP = "";
	EndIf;
	
	CheckTIN = True;
	CheckKPP = True;
	
	StructureToCheckTINandKPP = StructureToCheckTINandKPP(ThisForm, CheckTIN, CheckKPP);
	
	ValidateTINandKPP(StructureToCheckTINandKPP, ThisForm);
	
	CheckDuplicates(ThisForm);
	
	FormManagement(ThisForm);
	
EndProcedure // LegalEntityIndividualOnChange()

// Procedure - OnChange event handler of the TIN attribute
//
&AtClient
Procedure TINOnChange(Item)
	
	CheckTIN = True;
	CheckKPP = False;
	
	StructureToCheckTINandKPP = StructureToCheckTINandKPP(ThisForm, CheckTIN, CheckKPP);
	
	ValidateTINandKPP(StructureToCheckTINandKPP, ThisForm);
	
	CheckDuplicates(ThisForm);
	
	If ValueIsFilled(Object.TIN)
		AND Object.TINEnteredCorrectly 
		AND Not ValueIsFilled(Object.Description) Then
		
		ErrorDescription = "";
		FillAttributesUsingTINAtServer(ErrorDescription);
		
	EndIf;
	
	RunCounterpartyCheck();
	FillAttributesUsingTIN = False;
	AttachIdleHandler("Attachable_AllowFillingAttributesUsingTIN", 0.2, True);
	
EndProcedure

// Procedure - OnChange event handler of the KPP attribute
//
&AtClient
Procedure KPPOnChange(Item)
	
	CheckTIN = False;
	CheckKPP = True;
	
	StructureToCheckTINandKPP = StructureToCheckTINandKPP(ThisForm, CheckTIN, CheckKPP);
	
	ValidateTINandKPP(StructureToCheckTINandKPP, ThisForm);
	
	CheckDuplicates(ThisForm);
	RunCounterpartyCheck();
	
EndProcedure

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

&AtClient
Procedure FillAttributesWithTINExtendedTooltipProcessNavigationRefs(Item, URL, StandardProcessing)
	ProcessLinkClick(Item, URL, StandardProcessing);
EndProcedure

// Procedure - URLProcessing event handler of the IncorrectTINExplanationLabel item
//
&AtClient
Procedure LabelIncorrectTINExplanationsProcessNavigationRefs(Item, URL, StandardProcessing)
	ProcessLinkClick(Item, URL, StandardProcessing);
EndProcedure

// Procedure - URLProcessing event handler of the IncorrectKPPExplanationLabel item
//
&AtClient
Procedure LabelIncorrectKPPExplanationsProcessNavigationRefs(Item, URL, StandardProcessing)
	ProcessLinkClick(Item, URL, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FillAttributesWithTIN(Command)
	
	If Not FillAttributesUsingTIN Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.TIN) Then
		ShowMessageBox(, NStr("en='TIN field is not filled';lv='Lauks ""NMIN"" nav aizpildīts';ru='Поле ""ИНН"" не заполнено'"));
		CurrentItem = Items.TIN;
		Return;
	ElsIf Not Object.TINEnteredCorrectly Then
		ShowMessageBox(, String(LabelExplanationsOfIncorrectTIN));
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Description) Then
		QuestionText = NStr("az='Perezapolnit cari rekvizitlər?';en='Refill current attributes?';lv='Aizpildīt no jauna tekošos rekvizītus?';ru='Перезаполнить текущие реквизиты?'");
		NotifyDescription = New NotifyDescription("FillAttributesUsingTINEnd", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
	Else
		ExecuteFillingAttributesUsingTIN();
	EndIf;
	
EndProcedure

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

#Region TINandKPPCorrectness

&AtClientAtServerNoContext
Function StructureToCheckTINandKPP(Form, CheckTIN, CheckKPP)
	
	Object = Form.Object;
	StructureToCheckTINandKPP = New Structure();
	
	StructureToCheckTINandKPP.Insert("TIN",								   Object.TIN);
	StructureToCheckTINandKPP.Insert("KPP",								   Object.KPP);
	StructureToCheckTINandKPP.Insert("ThisIsLegalEntity", 						   Object.LegalEntityIndividual = PredefinedValue("Enum.LegalEntityIndividual.LegalEntity"));
	StructureToCheckTINandKPP.Insert("CheckTIN",					   CheckTIN);
	StructureToCheckTINandKPP.Insert("CheckKPP",					   CheckKPP);
	StructureToCheckTINandKPP.Insert("ColorHighlightIncorrectValues", Form.ColorHighlightIncorrectValues);
	
	Return StructureToCheckTINandKPP;
	
EndFunction

&AtClientAtServerNoContext
Procedure ValidateTINandKPP(ParametersStructure, Form)
	
	ReturnedStructure = SmallBusinessClientServer.CheckTINKPPCorrectness(ParametersStructure);
	
	FillPropertyValues(ParametersStructure, ReturnedStructure);
	
	FillPropertyValues(Form, ReturnedStructure);
	
	If Not Form.ReadOnly Then
		FillPropertyValues(Form.Object, ReturnedStructure);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function TINAndKPPAreCorrect(Form)
	
	Object = Form.Object;
	ThisIsLegalEntity = Object.LegalEntityIndividual = Form.LegalEntity;
	
	If ThisIsLegalEntity Then
		Result = Object.TINEnteredCorrectly AND (Object.KPPEnteredCorrectly Or Form.EmptyKPP);
	Else
		Result = Object.TINEnteredCorrectly;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region CheckingDuplicates

&AtClientAtServerNoContext
Procedure CheckDuplicates(Form)
	
	If Not Form.ReadOnly Then
		
		Object = Form.Object;
		DuplicateItemsNumber = 0;
// Rise { Bernavski N 2016-05-26
		If TINAndKPPAreCorrect(Form)  OR SmallBusinessReUse.GetValueByDefaultUser(UsersClientServer.CurrentUser(),"SearchDuplicatesOfCounterpartyWithoutCheckingCorrectnessTINAndKPP") Then
// Rise } Bernavski N 2016-05-26			
			DuplicateItemsNumber = SearchDuplicatesServer(Object.TIN, Object.KPP, Object.Ref);
			Form.ThereAreDuplicates = Not DuplicateItemsNumber = 0;
		Else
			Form.ThereAreDuplicates = False;
		EndIf;
		
		WriteInformationLabelsForDuplicates(Form, DuplicateItemsNumber);
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure WriteInformationLabelsForDuplicates(Form, Val DuplicateItemsNumber)
	
	Object = Form.Object;
	Items = Form.Items;
	
	ThisIsLegalEntity = Object.LegalEntityIndividual = Form.LegalEntity;
	
	If Form.ThereAreDuplicates Then
		
		DuplicatesMessageParametersStructure = New Structure;
		
		DuplicatesMessageParametersStructure.Insert("TINandKPP", ?(ThisIsLegalEntity, NStr("az='VÖENlər və KPP';bg='TIN and KPP';de='TIN and KPP';en='TIN and KPP';et='TIN and KPP';ka='TIN and KPP';lt='TIN and KPP';lv='NMIN un UUIK';mn='TIN and KPP';pl='TIN and KPP';ro='TIN and KPP';ru='ИНН и КПП';sl='TIN and KPP';tr='TIN and KPP'"), NStr("az='VÖEN';en='TIN';et='ИНН';lt='Reg. Nr.';lv='NMIN';ro='Nr. ORC:';ru='ИНН';tr='Vergi Kimlik No'")));
		
		If DuplicateItemsNumber = 1 Then
			DuplicatesMessageParametersStructure.Insert("DuplicateItemsNumber", NStr("az='Bir';bg='един';de='eins';en='one';et='üks';ka='ერთ-ერთი';lt='uno';lv='Viens';mn='нэг';pl='jeden';ro='unul';ru='Один';sl='ena';tr='bir'"));
			DuplicatesMessageParametersStructure.Insert("CounterpartyDeclension", NStr("az='kontragent';bg='контрагент';de='Kontrahent';en='counterparty';et='vastaspool';ka='კონტრაგენტის';lt='controparte';lv='kontrahents';mn='нөгөө тал';pl='kontrahenta';ro='contrapartidă';ru='контрагент';sl='nasprotne stranke';tr='karşı'"));
		ElsIf DuplicateItemsNumber < 5 Then
			DuplicatesMessageParametersStructure.Insert("DuplicateItemsNumber", DuplicateItemsNumber);
			DuplicatesMessageParametersStructure.Insert("CounterpartyDeclension", NStr("az='kontragent';bg='контрагент';de='Kontrahent';en='counterparty';et='vastaspool';ka='კონტრაგენტის';lt='controparte';lv='kontrahents';mn='нөгөө тал';pl='kontrahenta';ro='contrapartidă';ru='контрагент';sl='nasprotne stranke';tr='karşı'"));
		Else
			DuplicatesMessageParametersStructure.Insert("DuplicateItemsNumber", DuplicateItemsNumber);
			DuplicatesMessageParametersStructure.Insert("CounterpartyDeclension", NStr("az='müqabili';bg='контрагенти';de='Geschäftspartner';en='counterparties';et='vastaspoolte';ka='კონტრაგენტების';lt='controparti';lv='darījumu partneri';mn='талууд';pl='kontrahenci';ro='contrapărțile';ru='контрагенты';sl='nasprotne stranke';tr='karşı tarafın'"));
		EndIf;
		
		//Begin Bernavski Natalia [07.04.2016] 
		LabelTextOnDuplicates = NStr("en = 'With such [TINandKPP] there are [DuplicateItemsNumber] [CounterpartyDeclension]'");
		//End Bernavski Natalia [07.04.2016] 
	
		LabelExplanationsOfIncorrectTIN = StringFunctionsClientServer.SubstituteParametersInStringByName(LabelTextOnDuplicates, DuplicatesMessageParametersStructure);
		Form.LabelExplanationsOfIncorrectTIN = New FormattedString(LabelExplanationsOfIncorrectTIN,,Form.ColorHighlightIncorrectValues,,"ShowDoubles");
		
	Else
		
		If Object.TINEnteredCorrectly Then
			Form.LabelExplanationsOfIncorrectTIN = "";
		EndIf;
		
		If Object.KPPEnteredCorrectly Then
			Form.LabelExplanationsOfIncorrectKPP = "";
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SearchDuplicatesServer(Val TIN, Val KPP, Val Ref)
	
	DuplicateArray = Catalogs.Counterparties.CheckCatalogDuplicatesCounterpartiesByTINKPP(TrimAll(TIN), TrimAll(KPP));
	
	// Exclude the counterparty from the duplicates if there are no others
	If DuplicateArray.Count() = 1 AND DuplicateArray[0] = Ref Then
		DuplicateArray.Delete(0);
	EndIf;
	
	Return DuplicateArray.Count();
	
EndFunction

#EndRegion

#Region CheckFTSCounterparty

&AtClient
Procedure RunCounterpartyCheck()
	
	// If TIN or KPP are incorrect or Check is disabled, do not run the check
	If UseChecksAllowed Then
		
		CheckCounterparty(ThisForm);
		
		// Interrupt the previous check
		CheckResultInterval = 1;
		AttachIdleHandler("Attachable_ProcessCounterpartyCheckResult", CheckResultInterval, True);
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure CheckCounterparty(Form)
	
	Object = Form.Object;
	
	// Start a background job to check the counterparty
	LaunchParameters = New Structure;
	LaunchParameters.Insert("Counterparty", 	Object.Ref);
	LaunchParameters.Insert("TIN", 			Object.TIN);
	LaunchParameters.Insert("KPP", 			Object.KPP);
	LaunchParameters.Insert("StorageAddress", Form.StorageAddress);
	
	CounterpartiesCheckServerCall.CheckCounterpartyOnChange(LaunchParameters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure DisplayCounterpartyCheckResult(Form)
	
	Object = Form.Object;
	
	// Set header text
	If CounterpartiesCheckIsPossible(Form) AND ValueIsFilled(Form.CounterpartyState) Then
		
		TINWarningText = CounterpartiesCheckServerCall.CounterpartyCheckResultPresentation(Object.Ref, Object.TIN, Object.KPP, 
		Form.StorageAddress, Form.LabelExplanationsOfIncorrectTIN);
		
		Form.LabelExplanationsOfIncorrectTIN = TINWarningText;
		Form.LabelExplanationsOfIncorrectKPP = Undefined;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function CounterpartiesCheckIsPossible(Form)
	
	If Not Form.UseChecksAllowed Then
		Return False;
	EndIf;
	
	If Not TINAndKPPAreCorrect(Form) Then
		Return False;
	EndIf;
	
	Return True;

EndFunction

&AtClient
Procedure ProcessLinkClick(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	If Find(URL, "DetailsOnCounterpartiesCheck") > 0 Then
		CounterpartiesCheckClient.OpenServiceManual(StandardProcessing);
	ElsIf Find(URL, "CounterpartyVerificationsSetting") > 0 Then
		OpenForm("CommonForm.CounterpartyVerificationsSetting", , , "CounterpartyVerificationsSetting");
	Else
		HandleDuplicateChoiceSituation(Item);
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveCounterpartyCheckResultServer()
	
	CounterpartiesCheck.SaveCounterpartiesCheckResult(Object, StorageAddress);
	
EndProcedure

&AtClient
Procedure Attachable_ProcessCounterpartyCheckResult()
	
	CounterpartyState = CounterpartiesCheckServerCall.CurrentCounterpartyState(Object.Ref, Object.TIN, Object.KPP, StorageAddress);
	If Not ValueIsFilled(CounterpartyState) Then
		// Check the result after 1,3 and 9 sec
		If CheckResultInterval < 9 Then
			CheckResultInterval = CheckResultInterval * 3;
			AttachIdleHandler("Attachable_ProcessCounterpartyCheckResult", CheckResultInterval, True);
			Return;
		EndIf;
	Else
		// The result is received
		CounterpartyStateChanged = True;
		DisplayCounterpartyCheckResult(ThisForm);
	EndIf;
	
EndProcedure

#EndRegion

#Region FillingCounterpartyUSRLE

&AtClient
Procedure ExecuteFillingAttributesUsingTIN()
	
	ErrorDescription = "";
	FillAttributesUsingTINAtServer(ErrorDescription);
	
	// Check of the legal entity based on IFTS service data after filling the attributes (KPP may be changed)
	If Object.LegalEntityIndividual = LegalEntity
		AND CounterpartiesCheckIsPossible(ThisForm) 
		AND Not ValueIsFilled(CounterpartyState) Then
		CheckResultInterval = 1;
		AttachIdleHandler("Attachable_ProcessCounterpartyCheckResult", CheckResultInterval, True);
	EndIf;
	
	// Errors processor
	If ValueIsFilled(ErrorDescription) Then
		If ErrorDescription = "AuthenticationParametersAreNotSpecified" Then
		
			QuestionText = NStr("en='For automatic filling the"
"counterparty attributes it is necessary to connect to the user online support."
"Connect now?';ru='Для автоматического заполнения"
"реквизитов контрагентов необходимо подключиться к интернет-поддержке пользователей."
"Подключиться сейчас?'");
			NotifyDescription = New NotifyDescription("EnableInternetSupport", ThisObject);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
		Else
			ShowMessageBox(, ErrorDescription);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAttributesUsingTINAtServer(ErrorDescription = "")
	
	ThisIsLegalEntity = Object.LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
	If ThisIsLegalEntity Then
		CounterpartyAttributes = ServiceDataCommonGovRecords.LegalEntityDetailsByTIN(Object.TIN);
	Else
		CounterpartyAttributes = ServiceDataCommonGovRecords.EntrepreneurDetailsByTIN(Object.TIN);
	EndIf;
	If ValueIsFilled(CounterpartyAttributes.ErrorDescription) Then
		ErrorDescription = CounterpartyAttributes.ErrorDescription;
		Return;
	EndIf;
	
	FillPropertyValues(Object, CounterpartyAttributes);
	Object.DescriptionFull = CounterpartyAttributes.AbbreviatedName;
	
	If ThisIsLegalEntity Then
		
		// Filling addresses
		FillContactInformationItem(Catalogs.ContactInformationTypes.CounterpartyLegalAddress, CounterpartyAttributes.LegalAddress);
		FillContactInformationItem(Catalogs.ContactInformationTypes.CounterpartyFactAddress, CounterpartyAttributes.LegalAddress, False);
		
		// Phone filling
		FillContactInformationItem(Catalogs.ContactInformationTypes.CounterpartyPhone, CounterpartyAttributes.Phone);
		
		// Contact person filling
		If CounterpartyAttributes.Head <> Undefined 
			AND Not ValueIsFilled(Object.ContactPerson) Then
			
			ContactPersonData = CounterpartyAttributes.Head;
			PresentationOfContactPerson = ContactPersonData.Surname
				+ " " + ContactPersonData.Name
				+ " " + ContactPersonData.Patronymic
				+ ", " + ContactPersonData.Position;
			
		EndIf;
		
		// Check by KPP
		CheckTIN = False;
		CheckKPP = True;
		
		StructureToCheckTINandKPP = StructureToCheckTINandKPP(ThisForm, CheckTIN, CheckKPP);
		
		ValidateTINandKPP(StructureToCheckTINandKPP, ThisForm);
		
		CheckDuplicates(ThisForm);
		
		// Check of the legal entity based on IFTS service data after filling the attributes (KPP may be changed)
		If UseChecksAllowed Then
			
			CounterpartyState = CounterpartiesCheckServerCall.CurrentCounterpartyState(
				Object.Ref, Object.TIN, Object.KPP);
			StorageAddress 		 = CounterpartiesCheck.StorageAddressWithRestoredCounterpartyState(
				Object.Ref, Object.TIN, Object.KPP, UUID);
			
			If ValueIsFilled(CounterpartyState) Then
				DisplayCounterpartyCheckResult(ThisForm);
			Else
				CheckCounterparty(ThisForm);
			EndIf;
			
		EndIf;
		
	Else
		
		// Filling an ind. person
		If Not ValueIsFilled(Object.Individual) Then
			
			IndData = CounterpartyAttributes;
			ViewIndividuals = IndData.Surname
				+ " " + IndData.Name
				+ " " + IndData.Patronymic;
			
		EndIf;
		
	EndIf;
	
	FormManagement(ThisForm);
	Modified = True;
	
EndProcedure

&AtClient
Procedure FillAttributesUsingTINEnd(Response, AdditParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ExecuteFillingAttributesUsingTIN();
	EndIf;
	
EndProcedure 

&AtServer
Procedure FillContactInformationItem(CIKind, DataStructure, Refill = True)
	
	If DataStructure = Undefined Then
		Return;
	EndIf;
	
	Filter  = New Structure("Kind", CIKind);
	Rows = ThisForm.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
	RowData = ?(Rows.Count() = 0, Undefined, Rows[0]);
	If RowData = Undefined Or (NOT Refill AND ValueIsFilled(ThisForm[RowData.AttributeName])) Then
		Return;
	EndIf;
	FillPropertyValues(RowData, DataStructure);
	RowData.FieldsValues = DataStructure.ContactInformation;
	ThisForm[RowData.AttributeName] = DataStructure.Presentation;
	
EndProcedure

&AtClient
Procedure EnableInternetSupport(Response, AdditParameters) Export

	If Response = DialogReturnCode.Yes Then
		NotifyDescription = New NotifyDescription("ConnectOnlineUserSupportEnd", ThisObject, AdditParameters);
		OnlineUserSupportClient.ConnectOnlineUserSupport(NOTifyDescription);
	EndIf;

EndProcedure

&AtClient
Procedure ConnectOnlineUserSupportEnd(Result, AdditParameters) Export

	If Result <> Undefined Then
		ExecuteFillingAttributesUsingTIN();
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_AllowFillingAttributesUsingTIN()

	FillAttributesUsingTIN = True;

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

FillAttributesUsingTIN = True;

