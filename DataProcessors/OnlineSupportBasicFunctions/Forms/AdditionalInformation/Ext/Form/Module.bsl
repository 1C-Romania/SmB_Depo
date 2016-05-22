
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

&AtClient
Var RegistrationContext;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Items.LoginLabel.Title = NStr("en = 'Login:'") + " " + Parameters.login;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.GroupHeader.Representation = UsualGroupRepresentation.None;
		Items.GroupContent.Representation = UsualGroupRepresentation.None;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
	RegistrationContext = InteractionContext.COPContext.RegistrationContext;
	// Then the registration context is not used
	InteractionContext.COPContext.RegistrationContext = Undefined;
	
	ConfigureFormPresentation();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not SoftwareClosing Then
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	If CompanyBeforeChanging = Company Then
		Return;
	EndIf;
	
	// Configure the view of the form fields depending on whether a new company is added or an existing company is selected
	
	If Company = "-1" Then
		SetOnlyViewCompanyFields(False);
	Else
		SetOnlyViewCompanyFields(True);
	EndIf;
	
	If CompanyBeforeChanging = "-1" Then
		RegistrationContext.CompanyData["-1"] = NewCompanyData();
	EndIf;
	
	FillCompanyFieldData();
	
	CompanyBeforeChanging = Company;
	
EndProcedure

&AtClient
Procedure AddressClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	AddressFormName = "DataProcessor.OnlineSupportBasicFunctions.Form.MailAddress";
	
	FormParameters = New Structure("ReadOnly", (Company <> "-1"));
	
	If FormParameters.ReadOnly Then
		NotifyDescription = Undefined;
	Else
		NotifyDescription = New NotifyDescription("AtAddressEntry", ThisObject);
	EndIf;
	
	AddressForm = OpenForm(
		AddressFormName,
		FormParameters,
		ThisObject,
		,
		,
		,
		NotifyDescription);
	
	AddressForm.RegistrationContext = RegistrationContext;
	
	OnlineUserSupportClient.CopyValueListIteratively(
		RegistrationContext.Countries,
		AddressForm.Items.Country.ChoiceList);
	
	CountryStates = RegistrationContext.CountryStates[MailAddressInformation.Country];
	If CountryStates = Undefined Then
		CountryStates = New ValueList;
		CountryStates.Add("-1", NStr("en = '<Not selected>'"));
	EndIf;
	
	OnlineUserSupportClient.CopyValueListIteratively(
		CountryStates,
		AddressForm.Items.StateCode.ChoiceList);
	
	FillPropertyValues(AddressForm, MailAddressInformation);
	
EndProcedure

&AtClient
Procedure LabelLogoutClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure HeaderExplanationNavigationRefProcessing(Item, URL, StandardProcessing)
	
	If URL = "TechSupport" Then
		
		StandardProcessing = False;
		OnlineUserSupportClient.OpenDialogForSendingEmail(
			InteractionContext,
			MessageParametersToTechicalSupport());
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SendForm(Command)
	
	If Not FieldsAreFilledCorrectly() Then
		Return;
	EndIf;
	
	QueryParameters = New Array;
	
	organizationId = ?(Company = "-1", Undefined, Company);
	
	QueryParameters.Add(New Structure("Name, Value", "organizationId", organizationId));
	
	If organizationId = Undefined Then
		
		// Add data of a new company
		QueryParameters.Add(New Structure("Name, Value", "organizationName", CounterpartyName));
		QueryParameters.Add(New Structure("Name, Value", "typeActivity"    , BusinessType));
		QueryParameters.Add(New Structure("Name, Value", "tin"             , StrReplace(TIN, " ", "")));
		QueryParameters.Add(New Structure("Name, Value", "kpp"             , StrReplace(KPP, " ", "")));
		QueryParameters.Add(New Structure("Name, Value", "director"        , Head));
		QueryParameters.Add(New Structure("Name, Value", "PhoneNumber"     , Phone));
		QueryParameters.Add(New Structure("Name, Value", "email"           , EmailAddress));
		QueryParameters.Add(New Structure("Name, Value", "fax"             , Fax));
		
		QueryParameters.Add(New Structure("Name, Value",
			"postIndex",
			MailAddressInformation.IndexOf));
		
		QueryParameters.Add(New Structure("Name, Value",
			"countryId",
			?(MailAddressInformation.Country = "-1", Undefined, MailAddressInformation.Country)));
		
		QueryParameters.Add(New Structure("Name, Value",
			"regionId",
			?(MailAddressInformation.StateCode = "-1", Undefined, MailAddressInformation.StateCode)));
		
		QueryParameters.Add(New Structure("Name, Value",
			"area",
			MailAddressInformation.District));
		
		QueryParameters.Add(New Structure("Name, Value",
			"city",
			MailAddressInformation.City));
		
		QueryParameters.Add(New Structure("Name, Value",
			"street",
			MailAddressInformation.Street));
		
		QueryParameters.Add(New Structure("Name, Value",
			"building",
			MailAddressInformation.Building));
		
		QueryParameters.Add(New Structure("Name, Value",
			"housing",
			MailAddressInformation.Construction));
		
		QueryParameters.Add(New Structure("Name, Value",
			"apartment",
			MailAddressInformation.Apartment));
		
	EndIf;
	
	QueryParameters.Add(New Structure("Name, Value", "buyingPlace", WhereApplicationWasPurchased));
	QueryParameters.Add(New Structure("Name, Value", "buyingDate", XMLValueString(ApplicationPurchaseDate)));
	QueryParameters.Add(New Structure("Name, Value",
		"workPlaceCount",
		StrReplace(String(WorkplaceNumber), Char(160), "")));
	QueryParameters.Add(New Structure("Name, Value", "responsibleWorker", Responsible));
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	NotifyDescription = New NotifyDescription("WhenReplyingToRegistrationRejectIssue", ThisObject);
	
	ShowQueryBox(NOTifyDescription,
		NStr("en = 'Are you sure you want to cancel the registration of the software product?'"),
		QuestionDialogMode.YesNo,
		,
		,
		NStr("en = 'Software product registration'"));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ConfigureFormPresentation()
	
	CompanySelectingList = Items.Company.ChoiceList;
	
	OnlineUserSupportClient.CopyValueListIteratively(
		RegistrationContext.CompaniesList,
		CompanySelectingList);
	
	Company = "-1";
	
	MailAddressInformation = NewMailAddressData();
	AddressPresentation   = NStr("en = '<enter address>'");
	
EndProcedure

&AtClient
Procedure SetOnlyViewCompanyFields(OnlyViewFields)
	
	Items.CounterpartyName.ReadOnly     = OnlyViewFields;
	Items.BusinessType.ReadOnly         = OnlyViewFields;
	Items.TIN.ReadOnly                  = OnlyViewFields;
	Items.KPP.ReadOnly                  = OnlyViewFields;
	Items.Head.ReadOnly                 = OnlyViewFields;
	Items.Phone.ReadOnly                = OnlyViewFields;
	Items.EmailAddress.ReadOnly         = OnlyViewFields;
	Items.Fax.ReadOnly                  = OnlyViewFields;
	
EndProcedure

&AtClient
Function FieldsAreFilledCorrectly()
	
	Cancel = False;
	
	If Company = "-1" Then
		
		If IsBlankString(CounterpartyName) Then
			ShowFieldFillingErrorMessage(NStr("en = '""Company name"" field is not filled.'"),
				"CounterpartyName",
				Cancel);
		EndIf;
		
		If IsBlankString(BusinessType) Then
			ShowFieldFillingErrorMessage(NStr("en = '""Business type"" field is not filled.'"),
				"BusinessType",
				Cancel);
		EndIf;
		
		If IsBlankString(TIN) Then
			ShowFieldFillingErrorMessage(NStr("en = '""TIN"" field is not filled.'"),
				"TIN",
				Cancel);
		EndIf;
		
		If IsBlankString(Head) Then
			ShowFieldFillingErrorMessage(NStr("en = '""Manager"" field is not filled.'"),
				"Head",
				Cancel);
		EndIf;
		
		If IsBlankString(Phone) Then
			ShowFieldFillingErrorMessage(NStr("en = '""Phone"" field is not filled.'"),
				"Phone",
				Cancel);
		EndIf;
		
		If IsBlankString(EmailAddress) Then
			ShowFieldFillingErrorMessage(NStr("en = '""Email"" field is not filled.'"),
				"EmailAddress",
				Cancel);
		EndIf;
		
	EndIf;
	
	If IsBlankString(WhereApplicationWasPurchased) Then
		ShowFieldFillingErrorMessage(NStr("en = '""Purchase place"" field is not filled.'"),
			"WhereApplicationWasPurchased",
			Cancel);
	EndIf;
	
	If ApplicationPurchaseDate = '00010101' Then
		ShowFieldFillingErrorMessage(NStr("en = '""Purchase date"" field is not filled.'"),
			"ApplicationPurchaseDate",
			Cancel);
	EndIf;
	
	If WorkplaceNumber = 0 Then
		ShowFieldFillingErrorMessage(NStr("en = '""Number of Workplaces"" field is not filled.'"),
			"WorkplaceNumber",
			Cancel);
	EndIf;
	
	If IsBlankString(Responsible) Then
		ShowFieldFillingErrorMessage(NStr("en = '""Responsible employee"" field is not filled.'"),
			"Responsible",
			Cancel);
	EndIf;
	
	Return (NOT Cancel);
	
EndFunction

&AtClient
Procedure ShowFieldFillingErrorMessage(MessageText, FieldName, Cancel)
	
	Cancel = True;
	Message = New UserMessage;
	Message.Text = MessageText;
	Message.Field  = FieldName;
	Message.Message();
	
EndProcedure

&AtClient
Procedure WhenReplyingToRegistrationRejectIssue(QuestionResult, AdditParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ThisObject.Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure AtAddressEntry(EditedAddressData, AdditParameters) Export
	
	If TypeOf(EditedAddressData) <> Type("Structure") Then
		Return;
	EndIf;
	
	MailAddressInformation = EditedAddressData;
	GenerateAddressPresentation();
	
EndProcedure

&AtClient
Function NewCompanyData()
	
	Result = New Structure;
	
	Result.Insert("CounterpartyName", CounterpartyName);
	Result.Insert("typeActivity"       , BusinessType);
	Result.Insert("tin"                , TIN);
	Result.Insert("kpp"                , KPP);
	Result.Insert("director "          , Head);
	Result.Insert("PhoneNumber"        , Phone);
	Result.Insert("email"              , EmailAddress);
	Result.Insert("fax"                , Fax);
	
	Result.Insert("countryId"          , MailAddressInformation.Country);
	Result.Insert("regionId"           , MailAddressInformation.StateCode);
	Result.Insert("area"               , MailAddressInformation.District);
	Result.Insert("postindex"          , MailAddressInformation.IndexOf);
	Result.Insert("city"               , MailAddressInformation.City);
	Result.Insert("street"             , MailAddressInformation.Street);
	Result.Insert("building"           , MailAddressInformation.Building);
	Result.Insert("housing"            , MailAddressInformation.Construction);
	Result.Insert("apartment"          , MailAddressInformation.Apartment);
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function NewMailAddressData()
	
	Result = New Structure;
	Result.Insert("Country"    , "-1");
	Result.Insert("IndexOf"    , "");
	Result.Insert("StateCode", "-1");
	Result.Insert("District"     , "");
	Result.Insert("City"     , "");
	Result.Insert("Street"     , "");
	Result.Insert("Building"       , "");
	Result.Insert("Construction"  , "");
	Result.Insert("Apartment"  , "");
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillCompanyFieldData()
	
	CompanyCurrentData  = RegistrationContext.CompanyData[Company];
	MailAddressInformation = NewMailAddressData();
	
	If CompanyCurrentData = Undefined Then
		
		CounterpartyName     = "";
		BusinessType         = "";
		TIN                  = "";
		KPP                  = "";
		Head                 = "";
		Phone                = "";
		EmailAddress         = "";
		Fax                  = "";
		
	Else
		
		CompanyCurrentData.Property("CounterpartyName"    , CounterpartyName);
		CompanyCurrentData.Property("typeActivity"           , BusinessType);
		CompanyCurrentData.Property("tin"                    , TIN);
		CompanyCurrentData.Property("kpp"                    , KPP);
		CompanyCurrentData.Property("director"               , Head);
		CompanyCurrentData.Property("PhoneNumber"            , Phone);
		CompanyCurrentData.Property("email"                  , EmailAddress);
		CompanyCurrentData.Property("fax"                    , Fax);
		
		If CompanyCurrentData.Property("countryId") Then
			MailAddressInformation.Insert("Country",
				?(ValueIsFilled(CompanyCurrentData.countryId), CompanyCurrentData.countryId, "-1"));
		Else
			MailAddressInformation.Insert("Country", "-1");
		EndIf;
		
		If MailAddressInformation.Country = "-1" Then
			MailAddressInformation.Insert("StateCode", "-1");
		Else
			If CompanyCurrentData.Property("regionId") Then
				MailAddressInformation.Insert("StateCode",
					?(ValueIsFilled(CompanyCurrentData.regionId), CompanyCurrentData.regionId, "-1"));
			Else
				MailAddressInformation.Insert("StateCode", "-1");
			EndIf;
		EndIf;
		
		If CompanyCurrentData.Property("postindex") Then
			MailAddressInformation.Insert("IndexOf", CompanyCurrentData.postindex);
		EndIf;
		
		If CompanyCurrentData.Property("area") Then
			MailAddressInformation.Insert("District", CompanyCurrentData.area);
		EndIf;
		
		If CompanyCurrentData.Property("city") Then
			MailAddressInformation.Insert("City", CompanyCurrentData.city);
		EndIf;
		
		If CompanyCurrentData.Property("street") Then
			MailAddressInformation.Insert("Street", CompanyCurrentData.street);
		EndIf;
		
		If CompanyCurrentData.Property("building") Then
			MailAddressInformation.Insert("Building", CompanyCurrentData.building);
		EndIf;
		
		If CompanyCurrentData.Property("housing") Then
			MailAddressInformation.Insert("Construction", CompanyCurrentData.housing);
		EndIf;
		
		If CompanyCurrentData.Property("apartment") Then
			MailAddressInformation.Insert("Apartment", CompanyCurrentData.apartment);
		EndIf;
		
	EndIf;
	
	GenerateAddressPresentation();
	
EndProcedure

&AtClient
Procedure GenerateAddressPresentation()
	
	AddressPresentation = "";
	If MailAddressInformation.Country <> "-1" Then
		CountryListItem = RegistrationContext.Countries.FindByValue(MailAddressInformation.Country);
		If CountryListItem <> Undefined Then
			AddressPresentation = CountryListItem.Presentation;
		EndIf;
	EndIf;
	
	AddSubstring(AddressPresentation, MailAddressInformation.IndexOf);
	
	StatePresentation = "";
	If MailAddressInformation.StateCode <> "-1" Then
		CountryStates = RegistrationContext.CountryStates[MailAddressInformation.Country];
		If CountryStates <> Undefined Then
			ItemState = CountryStates.FindByValue(MailAddressInformation.StateCode);
			If ItemState <> Undefined Then
				StatePresentation = ItemState.Presentation;
			EndIf;
		EndIf;
	EndIf;
	
	AddSubstring(AddressPresentation, StatePresentation);
	
	AddSubstring(AddressPresentation, MailAddressInformation.District, NStr("en = 'district'") + " ");
	AddSubstring(AddressPresentation, MailAddressInformation.City, NStr("en = 'g.'") + " ");
	AddSubstring(AddressPresentation, MailAddressInformation.Street, NStr("en = 'st.'") + " ");
	AddSubstring(AddressPresentation, MailAddressInformation.Building, NStr("en = 'd.'") + " ");
	AddSubstring(AddressPresentation, MailAddressInformation.Construction, NStr("en = 'str.'") + " ");
	AddSubstring(AddressPresentation, MailAddressInformation.Apartment, NStr("en = 'app.'") + " ");
	
	If IsBlankString(AddressPresentation) Then
		If Company = "-1" Then
			AddressPresentation = NStr("en = '<enter address>'");
		Else
			AddressPresentation = NStr("en = '<Not filled>'");
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function XMLValueString(Val Value) Export
	Return XMLString(Value);
EndFunction

// Adding substring to string procedure
// Parameters
//     SourceLine - String - source string
//     Substring  - String - the string to be added to the end of source string
//     Prefix     - String - the string added before the substring
//     Delimiter  - String - the string being the separator between the string and substring
&AtClient
Procedure AddSubstring(SourceLine, Val Substring, Prefix = "", Delimiter = ", ")
	
	If Not IsBlankString(SourceLine) AND Not IsBlankString(Substring) Then
		SourceLine = SourceLine + Delimiter;
	EndIf;
	
	If Not IsBlankString(Substring) Then
		SourceLine = SourceLine + Prefix + Substring;
	EndIf;
	
EndProcedure

&AtClient
Function MessageParametersToTechicalSupport()
	
	MessageText = NStr("en = 'Hello!
		|I can not enter additional information of my company
		|when connecting to online support. Please help to solve the issue.
		|
		|Login: %1
   |Company name: %2
   |Business type: %3
   |TIN: %4
		|KPP: %5
		|Director: %6
		|Phone: %7
   |Email: %8
		|Fax: %9'");
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		MessageText,
		UserLogin,
		CounterpartyName,
		BusinessType,
		TIN,
		KPP,
		Head,
		Phone,
		EmailAddress,
		Fax);
	
	MessageTextContinued = NStr("en = 'Address: %1
    |Place of purchase: %2
    |Date of purchase: %3
    |Number of workplaces: %4
    |Responsible employee: %5
    |%TechnicalParameters%
    |-----------------------------------------------
    |Yours sincerely, .'");
	
	MessageTextContinued = StringFunctionsClientServer.PlaceParametersIntoString(
		MessageTextContinued,
		AddressPresentation,
		WhereApplicationWasPurchased,
		Format(ApplicationPurchaseDate, "L=en_EN; DF=dd.MM.yyyy; DLF=D"),
		String(WorkplaceNumber),
		Responsible);
	
	Result = New Structure;
	Result.Insert("Subject",
		NStr("en = 'Online support. Entry of user additional information.'"));
	Result.Insert("MessageText",
		MessageText + Chars.LF + MessageTextContinued);
	
	Return Result;
	
EndFunction

#EndRegion
