
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ThisIsCertificateAddition = (Parameters.ToAddCert = "YES");
	
	Items.LoginLabel.Title = NStr("en='Authorize:';ru='Авторизоваться:'") + " " + Parameters.login;
	
	RequestStatus           = Parameters.requestStatusED;
	RequestNumber            = Parameters.numberRequestED;
	ParticipantID = Parameters.identifierTaxcomED;
	ApplicationDateRow       = Parameters.dateRequestED;
	DSCertificate           = Parameters.IDDSCertificate;
	Company            = Parameters.IDOrganizationED;
	
	// Convert row parameters to a required kind
	RequestDate             = GetDateFromDateFromServerRow(ApplicationDateRow);
	
	SetFormStatus();
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.GroupInformation.Representation = UsualGroupRepresentation.None;
		Items.CertificateDataGroup.Representation = UsualGroupRepresentation.None;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
	If RequestStatus = "notconsidered" Then
		TimeoutSeconds = 60;
		SetLabelOnStatusUpdateHyperlink();
		AttachIdleHandler("EDFStatusUpdatesWaitingHandler", 1, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	DetachIdleHandler("EDFStatusUpdatesWaitingHandler");
	
	If RequestStatus = "obtained" Then
		
		FormID = OnlineUserSupportClientServer.SessionParameterValue(
			InteractionContext.COPContext,
			"IDParentForm");
		If TypeOf(FormID) <> Type("String") Then
			FormID = Undefined;
		Else
			Try
				FormID = New UUID(FormID);
			Except
				FormID = Undefined;
			EndTry;
		EndIf;
		
		Notify(
			"NotificationOfReceiptOfParticipantsUniqueIdEdExchange",
			ParticipantID,
			FormID);
		
	EndIf;
	
	If Not SoftwareClosing
		AND Not OnlineUserSupportClient.FormIsOpened(InteractionContext,
			"DataProcessor.Connection1CTaxcom.Form.SubscriberPersonalArea") Then
		// Close business process on server by a user
		OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ClickRefreshLabel(Item)
	
	DetachIdleHandler("EDFStatusUpdatesWaitingHandler");
	// Update application status
	OnlineUserSupportClient.ProcessFormCommand(
		InteractionContext,
		ThisObject,
		"getRequestStatus");
	
EndProcedure

&AtClient
Procedure LabelApplicationClick(Item)
	
	// Open application for view
	OnlineUserSupportClient.ProcessFormCommand(
		InteractionContext,
		Undefined,
		"showEDRequest");
	
EndProcedure

&AtClient
Procedure LabelPersonalAreaClick(Item)
	
	// Go to personal account
	OnlineUserSupportClient.ProcessFormCommand(
		InteractionContext,
		Undefined,
		"showPrivateED");
	
EndProcedure

&AtClient
Procedure LabelApplication1Click(Item)
	
	// Open application for view
	OnlineUserSupportClient.ProcessFormCommand(
		InteractionContext,
		Undefined,
		"showEDRequest");
	
EndProcedure

&AtClient
Procedure LabelChangeClick(Item)
	
	Connection1CTaxcomClient.ShowEDFApplicationRejection(InteractionContext);
	
EndProcedure

&AtClient
Procedure LabelLogoutClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure TechnicalSupportNavigationRefDataProcessor(Item, URL, StandardProcessing)
	
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
Procedure ExecuteAction(Command)
	
	If Not ValueIsFilled(RequestStatus)
		OR RequestStatus = "none"
		OR RequestStatus = "rejected" Then
		// New application
		
		OnlineUserSupportClient.ProcessFormCommand(
			InteractionContext,
			ThisObject,
			"newApplicationED");
		
	ElsIf RequestStatus = "obtained" Then
		
		// During closing of a form you will be
		// alerted about receiving identifier, also business-progress will be closed
		Close();
		
		// The button is invisible in other cases
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Converts date rows from IPP service format
// to internal date presentation in the platform.
//
// Parameters:
// -DateRow (Row) - date row in the YYYY-MM-DD hh:mm:ss format.
//
// Return value: Date - date converted to format of a platform date
&AtServer
Function GetDateFromDateFromServerRow(DateRow) Export
	
	If IsBlankString(DateRow) Then
		VariabDate = Date(1,1,1);
	Else
		Try
			VariabDate = Date(StrReplace
								(StrReplace
									(StrReplace
										(StrReplace
											(DateRow,
											".",
											""),
										"-",
										""),
									" ",
									""),
								":",
								""));
		Except
			VariabDate = Date(1,1,1);
		EndTry;
	EndIf;
	
	Return VariabDate;
	
EndFunction

// Procedure for setting an
// appearance of form kind depending on application status
&AtServer
Procedure SetFormStatus()
	
	If Not ValueIsFilled(RequestStatus)
		OR RequestStatus = "none" Then
		// New application
		
		Items.PageNotRegistered.Visible = True;
		Items.PageNotReviewed.Visible      = False;
		Items.PageReviewed.Visible        = False;
		Items.PageDenied.Visible           = False;
		
		Items.RegistrationInformationPanel.CurrentPage = Items.PageNotRegistered;
		Items.ExecuteAction.Title = NStr("en='Create request';ru='Создать заявку'");
		Items.ExecuteAction.Visible  = True;
		
	ElsIf RequestStatus = "notconsidered" Then
		// Awaited
		
		Items.PageNotRegistered.Visible = False;
		Items.PageNotReviewed.Visible      = True;
		Items.PageReviewed.Visible        = False;
		Items.PageDenied.Visible           = False;
		
		Items.RegistrationInformationPanel.CurrentPage = Items.PageNotReviewed;
		
		Items.ExecuteAction.Visible = False;
		Items.Close.DefaultButton   = True;
		Items.LabelApplication.Title = NStr("en='Request No';ru='Заявка №'")
			+ " " + ?(ValueIsFilled(RequestNumber), RequestNumber, "");
		If RequestDate <> Date(1,1,1) Then
			Items.LabelApplication.Title = Items.LabelApplication.Title
				+ " " + NStr("en='from';ru='from'") + " "
				+ Format(RequestDate, "DF = MMMM dd yyyy y. HH:mm:ss");
		EndIf;
		
		Items.Decoration4_1.Visible = ThisIsCertificateAddition;
		Items.Decoration4.Visible = Not Items.Decoration4_1.Visible;
		
	ElsIf RequestStatus = "rejected" Then
		// Rejected
		
		Items.PageNotRegistered.Visible = False;
		Items.PageNotReviewed.Visible      = False;
		Items.PageReviewed.Visible        = False;
		Items.PageDenied.Visible           = True;
		
		Items.RegistrationInformationPanel.CurrentPage = Items.PageDenied;
		Items.ExecuteAction.Title = NStr("en='Create request';ru='Создать заявку'");
		Items.ExecuteAction.Visible = True;
		Items.LabelApplication1.Title = NStr("en='Request No';ru='Заявка №'")
			+ " " + ?(ValueIsFilled(RequestNumber), RequestNumber, "");
		If RequestDate <> Date(1,1,1) Then
			Items.LabelApplication1.Title = Items.LabelApplication1.Title
				+ " " + NStr("en='from';ru='from'") + " "
				+ Format(RequestDate, "DF = MMMM dd yyyy y. HH:mm:ss");
		EndIf;
		
		Items.Decoration7_1.Visible = ThisIsCertificateAddition;
		Items.Decoration7.Visible   = Not Items.Decoration7_1.Visible;
		
	Else
		
		// Received RequestStatus = obtained
		
		Items.PageNotRegistered.Visible = False;
		Items.PageNotReviewed.Visible      = False;
		Items.PageReviewed.Visible        = True;
		Items.PageDenied.Visible           = False;
		
		Items.RegistrationInformationPanel.CurrentPage = Items.PageReviewed;
		Items.ExecuteAction.Title                  = "OK";
		Items.ExecuteAction.Visible                  = True;
		Items.LabelUUID.Title     = ?(ValueIsFilled(ParticipantID),
			ParticipantID,
			"");
		
		Items.Decoration6_1.Visible = ThisIsCertificateAddition;
		Items.Decoration6.Visible   = Not Items.Decoration6_1.Visible;
		
	EndIf;
	
EndProcedure

// Sets a label on hyperlink of an application status update - number
// of seconds before an auto update.
&AtClient
Procedure SetLabelOnStatusUpdateHyperlink()
	
	HeaderText = NStr("en='Check the request processing (%1 sec. left)';ru='Проверить выполнение заявки (осталось %1 сек.)'");
	HeaderText = StrReplace(HeaderText, "%1", String(TimeoutSeconds));
	Items.LabelRefresh.Title = HeaderText;
	
EndProcedure

// Processes waiting of an application status update
&AtClient
Procedure EDFStatusUpdatesWaitingHandler()
	
	If TimeoutSeconds < 1 Then
		
		DetachIdleHandler("EDFStatusUpdatesWaitingHandler");
		// Update application status
		OnlineUserSupportClient.ProcessFormCommand(
			InteractionContext,
			ThisObject,
			"getRequestStatus");
		
	Else
		
		TimeoutSeconds = TimeoutSeconds - 1;
		SetLabelOnStatusUpdateHyperlink();
		
	EndIf;
	
EndProcedure

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en='1C-Taxcom. ED exchange participant request for registration';ru='1С-Такском. Заявка на регистрацию участника обмена ЭД'"));
	Result.Insert("Whom", "1c-taxcom@1c.ru");
	
	MessageText = NStr("en='Hello! I can not send an application to register ED exchange participant. Would you help me to solve the problem? Login: %1. %2 %TechnicalParameters% ----------------------------------------------- Sincerely, .';ru='Здравствуйте! У меня не получается отправить заявку на регистрацию участника обмена ЭД. Прошу помочь разобраться с проблемой. Логин: %1. %2 %ТехническиеПараметры% 
		|----------------------------------------------- С уважением, .'");
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		MessageText,
		UserLogin,
		Connection1CTaxcomClient.TechnicalEDFParametersText(InteractionContext, DSCertificate));
	
	Result.Insert("MessageText", MessageText);
	Result.Insert("ConditionalRecipientName",
		InteractionContext.COPContext.MainParameters.LaunchLocation);
	
	Return Result;
	
EndFunction

#EndRegion
