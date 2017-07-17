
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	// Create structure with the processor attributes.
	
	Items.LoginLabel.Title = NStr("en='Authorize:';ru='Авторизоваться:'") + " " + Parameters.login;
	
	FormStatus      = Parameters.statusApplicationFormED;
	RequestNumber      = Parameters.numberRequestED;
	RowRequestDate = Parameters.dateRequestED;
	RequestStatus     = Parameters.requestStatusED;
	
	If Not IsBlankString(RowRequestDate) Then
		Try
			RequestDate = Date(StrReplace(StrReplace(StrReplace(RowRequestDate, "-", "")," ",""), ":",""));
		Except
			RequestDate = Date(1,1,1);
		EndTry;
	Else
		RequestDate = Date(1,1,1);
	EndIf;
	
	If FormStatus = "new" OR Not ValueIsFilled(FormStatus) Then
		
		Items.FormHeaderLabel.Title = NStr("en='ED exchange participant request for registration';ru='Заявка на регистрацию участника обмена ЭД'");
		Items.RequestStatusLabel.Title = NStr("en='New request';ru='Новая заявка'");
		Items.SendApplication.Visible = True;
		
		Items.ApplicationForRegistrationPages.CurrentPage = Items.ApplicationForRegistrationPage;
		
	ElsIf FormStatus = "change" Then
		
		Items.FormHeaderLabel.Title = NStr("en='Change data of ED exchange participant';ru='Изменение данных участника обмена ЭД'");
		Items.RequestStatusLabel.Title = NStr("en='New request';ru='Новая заявка'");
		Items.SendApplication.Visible = True;
		
		Items.ApplicationForRegistrationPages.CurrentPage = Items.ApplicationForChangePage;
		
	ElsIf FormStatus = "show" Then
		
		HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Request No %1, %2';ru='Заявка №%1 от %2'"),
			RequestNumber,
			Format(RequestDate, "DF = mm dd yyyy y.  HH:mm:ss"));
		
		Items.FormHeaderLabel.Title = HeaderText;
		
		Items.SendApplication.Visible = False;
		Items.Close.DefaultButton = True;
		
		DSCertificate = Parameters.nameDSCertificate;
		
		If Not ValueIsFilled(DSCertificate) Then
			Items.DSCertificate.Visible = False;
		EndIf;
		
		Items.DSCertificate.ChoiceButton = False;
		Items.ApplicationForRegistrationPages.CurrentPage = Items.ApplicationForChangePage;
		ReadOnly = True;
		
	EndIf;
	
	If Not ValueIsFilled(RequestStatus) OR RequestStatus = "none" Then
		
		TextStatus = NStr("en='New request.';ru='Новая заявка.'");
		Items.CauseLabel.Visible = False;
		
	ElsIf RequestStatus = "notconsidered" Then
		
		TextStatus = NStr("en='Provider has not reviewed your request yet.';ru='Заявка оператором еще не рассмотрена.'");
		Items.CauseLabel.Visible = False;
		
	ElsIf RequestStatus = "rejected" Then
		
		TextStatus = NStr("en='Provider rejected the request.';ru='Заявка оператором отклонена.'");
		Items.CauseLabel.Visible = True;
		
	Else
		
		// RequestStatus = obtained
		TextStatus = NStr("en='The request is successfully processed by the provider';ru='Заявка успешно выполнена оператором'");
		Items.CauseLabel.Visible = False;
		
	EndIf;
	
	Items.RequestStatusLabel.Title = TextStatus;
	
	// Update information about company
	UpdateCompanyInformation();
	
	If ReadOnly Then
		Items.Address.ChoiceButton   = False;
		Items.Address.OpenButton = True;
	Else
		Items.Address.ChoiceButton   = True;
		Items.Address.OpenButton = False;
	EndIf;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.CommentGroup.Representation = UsualGroupRepresentation.None;
		Items.CompanyInformationGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.ContactInformationGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.CompanyHeadInformationGroup.Representation = UsualGroupRepresentation.WeakSeparation;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not SoftwareClosing Then
		
		If ThisObject.Modified Then
			
			Cancel = True;
			NotifyDescription = New NotifyDescription("OnAnswerQuestionAboutClosingModifiedForm",
				ThisObject);
			
			QuestionText = NStr("en='Data was changed. Close the form without saving data?';ru='Данные изменены. Закрыть форму без сохранени данных?'");
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
			
		EndIf;
		
		If FormStatus <> "show" AND Not SendButtonIsPressed Then
			
			QueryParameters = New Array;
			QueryParameters.Add(New Structure("Name, Value", "endForm", "close"));
			// Shows that the Close button is clicked
			
			// Send parameters to server
			OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext,
				ThisObject,
				QueryParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure StartAddressSelection(Item, ChoiceData, StandardProcessing)
	
	// Prepare data and open form for entering address
	StandardProcessing = False;
	SelectAddress(False);
	
EndProcedure

&AtClient
Procedure AddressOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	SelectAddress(True);
	
EndProcedure

&AtClient
Procedure LabelCauseClick(Item)
	
	Connection1CTaxcomClient.ShowEDFApplicationRejection(InteractionContext);
	
EndProcedure

&AtClient
Procedure LabelLogoutClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	SettingsByLegalEntityIndividual();
	
EndProcedure

&AtClient
Procedure DecorationTechnicalSupportNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
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
Procedure SendApplication(Command)
	
	// Check if required fields are filled in
	Error = False;
	
	If IsBlankString(Company) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='Company is not filled in';ru='Не заполнено поле ""Организация""'");
		Message.Field = "Company";
		Message.Message();
	EndIf;
	
	If IsBlankString(Address) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Address"" field is required';ru='Не заполнено поле ""Адрес""'");
		Message.Field = "Address";
		Message.Message();
	EndIf;
	
	If IsBlankString(Phone) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Phone"" field is required';ru='Не заполнено поле ""Телефон""'");
		Message.Field = "Phone";
		Message.Message();
	EndIf;
	
	// Check address
	
	If IsBlankString(StateCode) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text =
			NStr("en='Region code is not specified (Specify a region code in the ""ED exchange participant address"" form)';ru='Не указан ""Код региона"" (Код региона нужно указать в форме ""Адрес участника обмена ЭД"")'");
		Message.Field = "Address";
		Message.Message();
	EndIf;
	
	If IsBlankString(TIN) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='Field ""TIN"" is not entered';ru='Не заполнено поле ""ИНН""'");
		Message.Field = "TIN";
		Message.Message();
	EndIf;
	
	If LegalEntityIndividual <> "LegalEntity" AND LegalEntityIndividual <> "Ind" Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='Company type (legal entity or individual) is not selected';ru='Не выбран тип организации (юридическое или физическое лицо)'");
		Message.Field = "LegalEntityIndividual";
		Message.Message();
	EndIf;
	
	If IsBlankString(OGRN) AND LegalEntityIndividual = "LegalEntity" Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='The ""OGRN"" field is required';ru='Не заполнено поле ""ОГРН""'");
		Message.Field = "OGRN";
		Message.Message();
	EndIf;
	
	If IsBlankString(TaxAuthorityCode) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='Tax authority code is not filled in';ru='Не заполнено поле ""Код налогового органа""'");
		Message.Field = "TaxAuthorityCode";
		Message.Message();
	EndIf;
	
	If IsBlankString(Surname) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Last name"" field is not filled in';ru='Не заполнено поле ""Фамилия""'");
		Message.Field = "Surname";
		Message.Message();
	EndIf;
	
	If IsBlankString(Name) Then
		Error    = True;
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Name"" field is required';ru='Не заполнено поле ""Имя""'");
		Message.Field = "Name";
		Message.Message();
	EndIf;
	
	// Additional checks
	
	If Not IsBlankString(Phone) Then
		If StrLen(Phone) > 20 Then
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en='Phone should contain 20 or fewer characters.';ru='""Телефон"" должен содержать не более 20 символов'");
			Message.Field = "Phone";
			Message.Message();
		EndIf;
	EndIf;
	
	If Not IsBlankString(StateCode) Then
		Try
			StateCodeNumber = Number(TrimAll(StateCode));
			If StrLen(TrimAll(StateCode)) <> 2 Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en='Region code should contain 2 digits';ru='""Код региона"" должен содержать 2 цифры'");
				Message.Field = "Address";
				Message.Message();
			Else
				If StateCodeNumber > 99 OR StateCodeNumber < 1 Then
					Error    = True;
					Message = New UserMessage;
					Message.Text = NStr("en='Region code should be from 01 to 99';ru='""Код региона"" должен быть от 01 до 99'");
					Message.Field = "StateCode";
					Message.Message();
				EndIf;
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en='Invalid characters are used in the region code';ru='В ""Коде региона"" использованы недопустимые символы'");
			Message.Field = "Address";
			Message.Message();
		EndTry;
	EndIf;
	
	If Not IsBlankString(TIN) Then
		Try
			TINNumber = Number(TrimAll(TIN));
			If StrLen(TrimAll(TIN)) <> 12 AND LegalEntityIndividual = "Ind" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en='TIN should contain 12 digits';ru='""ИНН"" должен содержать 12 цифр'");
				Message.Field = "TIN";
				Message.Message();
			ElsIf StrLen(TrimAll(TIN)) <> 10 AND LegalEntityIndividual = "LegalEntity" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en='TIN should contain 10 digits';ru='""ИНН"" должен содержать 10 цифр'");
				Message.Field = "TIN";
				Message.Message();
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en='Invalid characters are used in ""TIN""';ru='В ""ИНН"" использованы недопустимые символы'");
			Message.Field = "TIN";
			Message.Message();
		EndTry;
	EndIf;
	
	If Not IsBlankString(OGRN) Then
		Try
			OGRNNumber = Number(TrimAll(OGRN));
			If StrLen(TrimAll(OGRN)) <> 13  AND LegalEntityIndividual = "LegalEntity" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en='OGRN should contain 13 digits';ru='""ОГРН"" должен содержать 13 цифр'");
				Message.Field = "OGRN";
				Message.Message();
			ElsIf StrLen(TrimAll(OGRN)) <> 15  AND LegalEntityIndividual = "Ind" Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en='OGRN should contain 15 digits';ru='""ОГРН"" должен содержать 15 цифр'");
				Message.Field = "OGRN";
				Message.Message();
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en='Invalid characters are used in ""OGRN""';ru='В ""ОГРН"" использованы недопустимые символы'");
			Message.Field = "OGRN";
			Message.Message();
		EndTry;
	EndIf;
	
	If Not IsBlankString(TaxAuthorityCode) Then
		Try
			TaxAuthorityNumberCode = Number(TrimAll(TaxAuthorityCode));
			If StrLen(TrimAll(TaxAuthorityCode)) <> 4 Then
				Error    = True;
				Message = New UserMessage;
				Message.Text = NStr("en='Tax authority code must contain 4 digits';ru='""Код налогового органа"" должен содержать 4 цифры'");
				Message.Field = "TaxAuthorityCode";
				Message.Message();
			EndIf;
		Except
			Error    = True;
			Message = New UserMessage;
			Message.Text = NStr("en='Invalid characters are used in ""Tax authority code""';ru='В ""Коде налогового органа"" использованы недопустимые символы'");
			Message.Field = "TaxAuthorityCode";
			Message.Message();
		EndTry;
	EndIf;
	
	If Error Then
		Return;
	EndIf;
	
	// Pass data to server
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "endForm"           , "send"));
	// Shows that the Send button is clicked
	
	QueryParameters.Add(New Structure("Name, Value", "postindexED"       , IndexOf));
	QueryParameters.Add(New Structure("Name, Value", "addressregionED"   , Region));
	QueryParameters.Add(New Structure("Name, Value", "codregionED"       , StateCode));
	QueryParameters.Add(New Structure("Name, Value", "addresstownshipED" , District));
	QueryParameters.Add(New Structure("Name, Value", "addresscityED"     , City));
	QueryParameters.Add(New Structure("Name, Value", "addresslocalityED" , Settlement));
	QueryParameters.Add(New Structure("Name, Value", "addressstreetED"   , Street));
	QueryParameters.Add(New Structure("Name, Value", "addressbuildingED" , Building));
	QueryParameters.Add(New Structure("Name, Value", "addresshousingED"  , Section));
	QueryParameters.Add(New Structure("Name, Value", "addressapartmentED", Apartment));
	QueryParameters.Add(New Structure("Name, Value", "addressphoneED"    , Phone));
	QueryParameters.Add(New Structure("Name, Value", "agencyED"          , Company));
	QueryParameters.Add(New Structure("Name, Value", "tinED"             , TIN));
	QueryParameters.Add(New Structure("Name, Value", "ogrnED"            , OGRN));
	QueryParameters.Add(New Structure("Name, Value", "codeimnsED"        , TaxAuthorityCode));
	QueryParameters.Add(New Structure("Name, Value", "lastnameED"        , Surname));
	QueryParameters.Add(New Structure("Name, Value", "firstnameED"       , Name));
	QueryParameters.Add(New Structure("Name, Value", "middlenameED"      , Patronymic));
	QueryParameters.Add(New Structure("Name, Value", "identifierTaxcomED", CompanyID));
	QueryParameters.Add(New Structure("Name, Value", "orgindED"          , LegalEntityIndividual));
	QueryParameters.Add(New Structure("Name, Value", "addressED"         , Address));
	
	If FormStatus <> "show" Then
		
		If ValueIsFilled(DSCertificate) Then
			
			PreviousCertificate = OnlineUserSupportClientServer.SessionParameterValue(
				InteractionContext.COPContext,
				"IDDSCertificate");
			
			CertificatePresentation = "";
			CertificateBinaryData = CertificateBinaryData(DSCertificate, CertificatePresentation);
			
			If DSCertificate <> PreviousCertificate Then
				
				OnlineUserSupportClientServer.WriteContextParameter(
					InteractionContext.COPContext,
					"IDDSCertificate_Dop",
					DSCertificate);
				
			EndIf;
			
			QueryParameters.Add(New Structure("Name, Value", "nameDSCertificate", CertificatePresentation));
			
			If CertificateBinaryData <> Undefined Then
				
				StringBase64 = Base64String(CertificateBinaryData);
				QueryParameters.Add(New Structure("Name, Value", "certificateED", StringBase64));
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ThisObject.Modified = False;
	SendButtonIsPressed = True;
	
	// Send parameters to server
	
	OnlineUserSupportClient.ServiceCommandsDataProcessor(
		InteractionContext,
		ThisObject,
		QueryParameters);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure that receives information
// about company from the configuration by company data
&AtServer
Procedure UpdateCompanyInformation()
	
	LegalEntityIndividual                = Parameters.orgindED;
	IndexOf                   = Parameters.postindexED;
	Region                   = Parameters.addressregionED;
	StateCode               = Parameters.coderegionED;
	District                    = Parameters.addresstownshipED;
	City                    = Parameters.addresscityED;
	Settlement          = Parameters.addresslocalityED;
	Street                    = Parameters.addressstreetED;
	Building                      = Parameters.addressbuildingED;
	Section                   = Parameters.addresshousingED;
	Apartment                 = Parameters.addressapartmentED;
	Phone                  = Parameters.addressphoneED;
	Company              = Parameters.agencyED;
	TIN                      = Parameters.tinED;
	OGRN                     = Parameters.ogrnED;
	TaxAuthorityCode      = Parameters.codeimnsED;
	Surname                  = Parameters.lastnameED;
	Name                      = Parameters.firstnameED;
	Patronymic                 = Parameters.middlenameED;
	CompanyID = Parameters.identifierTaxcomED;
	
	If FormStatus <> "show" Then
		DSCertificate = Parameters.IDDSCertificate;
	EndIf;
	
	GenerateAddress();
	
	LegalEntityIndividual = ?(IsBlankString(LegalEntityIndividual), "LegalEntity", LegalEntityIndividual);
	
	SettingsByLegalEntityIndividual();
	
EndProcedure

// Procedure of setting
// the form items depending on the LegalEntityIndividual switcher
&AtServer
Procedure SettingsByLegalEntityIndividual()
	
	If LegalEntityIndividual = "LegalEntity" Then
		Items.OGRN.AutoMarkIncomplete = True;
	Else
		Items.OGRN.AutoMarkIncomplete = False;
	EndIf;
	
EndProcedure

// Generates address row by address attributes
&AtServer
Procedure GenerateAddress() Export
	
	Addr = "";
	
	AddSubstring(Addr, IndexOf);
	AddSubstring(Addr, Region);
	AddSubstring(Addr, StateCode, "Region ");
	AddSubstring(Addr, District);
	AddSubstring(Addr, City);
	AddSubstring(Addr, Settlement);
	AddSubstring(Addr, Street);
	AddSubstring(Addr, Building     , "h. ");
	AddSubstring(Addr, Section  , "build. ");
	AddSubstring(Addr, Apartment, "appartment ");
	
	Address = Addr;
	
EndProcedure

// Procedure of adding a
// subrow to the Parameters row:
// - SourceRow - String - source row;
// - Subrow      - String - String that should be added to the end of a source row;
// - Prefix        - String - String that is added before the subrow;
// - Separator    - String - String that serves as a separator between a row and a subrow
//
&AtServer
Procedure AddSubstring(SourceLine, Val Substring, Prefix = "", Delimiter = ", ")
	
	If Not IsBlankString(SourceLine) AND Not IsBlankString(Substring) Then
		SourceLine = SourceLine + Delimiter;
	EndIf;
	
	If Not IsBlankString(Substring) Then
		SourceLine = SourceLine + Prefix + Substring;
	EndIf;
	
EndProcedure

// Receives binary data of a certificate by calling
// a corresponding function of the server predefined module.
//
// Parameters:
// - CertificateRef (AnyRef) - ref to data object containing certificate data
//
// Return value: BinaryData - if it was impossible to
// 					  receive certificate binary data, Undefined - otherwise.
//
&AtServerNoContext
Function CertificateBinaryData(Val CertificatRef, CertificatePresentation)
	
	CertificatePresentation = String(CertificatRef);
	CertificateBinaryData = Connection1CTaxcom.CertificateBinaryData(CertificatRef);
	
	Return CertificateBinaryData;
	
EndFunction

// Opens an address selection form in the
// modal mode and returns address attributes in the form of structure with the corresponding fields
//
// Parameters:
// - ViewOnly (Boolean): True - open form of selecting address for view only
//
// Return value: Structure with fields - address attributes;
// 					  Undefined if the OK button was not clicked in the address form during closing
// 
&AtClient
Procedure SelectAddress(ViewOnly = False)
	
	FormParameters = New Structure("ReadOnly", ViewOnly);
	
	If ViewOnly Then
		ClosingAlert = Undefined;
	Else
		ClosingAlert = New NotifyDescription("OnSelectAddress", ThisObject);
	EndIf;
	
	FormParameters.Insert("IndexOf"    , IndexOf);
	FormParameters.Insert("Region"    , Region);
	FormParameters.Insert("District"     , District);
	FormParameters.Insert("City"     , City);
	FormParameters.Insert("Settlement"  , Settlement);
	FormParameters.Insert("Street"     , Street);
	FormParameters.Insert("Building"       , Building);
	FormParameters.Insert("Section"    , Section);
	FormParameters.Insert("Apartment"  , Apartment);
	FormParameters.Insert("StateCode", StateCode);
	
	AddressOutputForm = OpenForm("DataProcessor.Connection1CTaxcom.Form.EDExchangeParticipantAddress",
		FormParameters,
		,
		,
		,
		,
		ClosingAlert);
	
	AddressOutputForm.InteractionContext = InteractionContext;
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, AddressOutputForm);
	
EndProcedure

&AtClient
Procedure OnSelectAddress(AddressParameters, AdditParameters) Export
	
	If TypeOf(AddressParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Set modification by passed data
	If Not ThisObject.Modified Then
		If    IndexOf          <> AddressParameters.IndexOf
			OR Region          <> AddressParameters.Region
			OR District           <> AddressParameters.District
			OR City           <> AddressParameters.City
			OR Settlement <> AddressParameters.Settlement
			OR Street           <> AddressParameters.Street
			OR Building             <> AddressParameters.Building
			OR Section          <> AddressParameters.Section
			OR Apartment        <> AddressParameters.Apartment
			OR StateCode      <> AddressParameters.StateCode Then
			
			ThisObject.Modified = True;
		EndIf;
	EndIf;
	
	// If address is changed, then changes
	IndexOf          = AddressParameters.IndexOf;
	Region          = AddressParameters.Region;
	District           = AddressParameters.District;
	City           = AddressParameters.City;
	Settlement = AddressParameters.Settlement;
	Street           = AddressParameters.Street;
	Building             = AddressParameters.Building;
	Section          = AddressParameters.Section;
	Apartment        = AddressParameters.Apartment;
	StateCode      = AddressParameters.StateCode;
	
	GenerateAddress();
	
EndProcedure

&AtClient
Procedure OnAnswerQuestionAboutClosingModifiedForm(QuestionResult, AdditParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en='1C-Taxcom. ED exchange participant request for registration';ru='1С-Такском. Заявка на регистрацию участника обмена ЭД'"));
	Result.Insert("Whom", "1c-taxcom@1c.ru");
	
	MessageText = NStr("en='Dear Sir or Madam, %1. Please help me to deal with the issue. Login: %2. %3 %TechnicalParameters% ----------------------------------------------- Sincerely, .';ru='Здравствуйте! %1. Прошу помочь разобраться с проблемой. Логин: %2. %3 %ТехническиеПараметры% ----------------------------------------------- С уважением, .'");
	
	If FormStatus = "new" OR IsBlankString(FormStatus) Then
		WhatFailed = NStr("en='I cannot send a request for ED exchange participant registration';ru='У меня не получается отправить заявку на регистрацию участника обмена ЭД'");
	ElsIf FormStatus = "change" Then
		WhatFailed = NStr("en='I cannot send a request for changing ED exchange participant data';ru='У меня не получается отправить заявку на изменение данных участника обмена ЭД'");
	ElsIf FormStatus = "show" Then
		WhatFailed = NStr("en='I had some problems with an ED exchange participant request';ru='У меня возникли проблемы с заявкой участника обмена ЭД'");
	EndIf;
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		MessageText,
		WhatFailed,
		UserLogin,
		Connection1CTaxcomClient.TechnicalEDFParametersText(InteractionContext, DSCertificate));
	
	Result.Insert("MessageText", MessageText);
	Result.Insert("ConditionalRecipientName",
		InteractionContext.COPContext.MainParameters.LaunchLocation);
	
	Return Result;
	
EndFunction

#EndRegion
