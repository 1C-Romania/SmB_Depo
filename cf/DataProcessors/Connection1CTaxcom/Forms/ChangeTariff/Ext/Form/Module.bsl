
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	// Fill in form fields
	Items.LoginLabel.Title = NStr("en='Login:';ru='Авторизоваться:'") + " " + Parameters.login;
	
	FreePackagesRow = StrReplace(
		TrimAll(Parameters.freePackagesED),
			   Char(160),
			   "");
	RowUnallocated =  StrReplace(
		TrimAll(Parameters.unallocatedPackagesED),
			   Char(160),
			   "");
	
	BeginningDateRow    = Parameters.begindatetarifED;
	EndDateRow = Parameters.enddatetarifED;
	ApplicationDateRow    = Parameters.dateRequestED;
	RequestNumber         = Parameters.numberRequestED;
	EDRequestStatus      = Parameters.requestStatusED;
	DenialCode           = Parameters.codeErrorED;
	DenialText         = Parameters.textErrorED;
	
	RequestDate    = GetDateFromDateFromServerRow(ApplicationDateRow);
	StartDate    = GetDateFromDateFromServerRow(BeginningDateRow);
	EndDate = GetDateFromDateFromServerRow(EndDateRow);
	
	Try
		FreePackages = Number(FreePackagesRow);
	Except
		FreePackages = 0;
	EndTry;
	
	Try
		Unallocated = Number(RowUnallocated);
	Except
		Unallocated = 0;
	EndTry;
	
	MaximumTariff = FreePackages + Unallocated;
	
	MaxTariffRow = StrReplace(String(MaximumTariff), Char(160), "");
	InvitationText = Items.ApplicationIssueLabel.Title;
	Items.ApplicationIssueLabel.Title = StrReplace(InvitationText, "1000", MaxTariffRow);
	
	Items.FreePackages.MaxValue = MaximumTariff;
	
	HeaderText = NStr("en='Period: from %1 to %2';ru='Период: с %1 по %2'");
	HeaderText = StrReplace(HeaderText, "%1", Format(StartDate, "DLF=D"));
	HeaderText = StrReplace(HeaderText, "%2", Format(EndDate, "DLF=D"));
	
	Items.BillingPeriod.Title = HeaderText;
	
	ApplicationTitle = NStr("en='Application No%1 from %2';ru='Заявка №%1 от %2'");
	ApplicationTitle = StrReplace(ApplicationTitle, "%1", RequestNumber);
	ApplicationTitle = StrReplace(ApplicationTitle, "%2", Format(RequestDate, "DF = MMMM dd yyyy y. HH:mm:ss"));
	
	Items.LabelApplication.Title  = ApplicationTitle;
	Items.LabelApplication1.Title = ApplicationTitle;
	Items.LabelApplication2.Title = ApplicationTitle;
	
	ProcessFormStatus();
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.RequestStatusGroup.Representation = UsualGroupRepresentation.None;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnlineUserSupportClient.HandleFormOpening(InteractionContext, ThisObject);
	
	If EDRequestStatus = "notconsidered" Then
		
		TimeoutSeconds = 60;
		SetLabelOnStatusUpdateHyperlink();
		AttachIdleHandler("EDFStatusUpdatesWaitingHandler", 1, False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not SoftwareClosing Then
		
		If ThisObject.Modified Then
			
			Cancel = True;
			NotifyDescription = New NotifyDescription("OnAnswerQuestionAboutClosingModifiedForm",
				ThisObject);
			
			QuestionText = NStr("en='Data was changed. Close form without saving data?';ru='Данные изменены. Закрыть форму без сохранени данных?'");
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
			
		EndIf;
		
		If Not ChangeButtonIsPressed Then
			
			// User closes the application
			QueryParameters = New Array;
			QueryParameters.Add(New Structure("Name, Value", "endForm", "close"));
			
			// Send parameters to server
			OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure NavigationRefDataProcessorMessageToTechSupport(Item, URL, StandardProcessing)
	
	If URL = "TechSupport" Then
		StandardProcessing = False;
		OnlineUserSupportClient.OpenDialogForSendingEmail(
			InteractionContext,
			MessageParametersToTechicalSupport());
	EndIf;
	
EndProcedure

&AtClient
Procedure LabelLogoutClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
EndProcedure

&AtClient
Procedure FreePackagesOnChange(Item)
	
	Unallocated = MaximumTariff - FreePackages;
	
EndProcedure

&AtClient
Procedure LabelCauseClick(Item)
	
	Connection1CTaxcomClient.ShowEDFApplicationRejection(InteractionContext);
	
EndProcedure

&AtClient
Procedure ClickRefreshLabel(Item)
	
	// Update application status
	OnlineUserSupportClient.ProcessFormCommand(
		InteractionContext,
		ThisObject,
		"getRequestStatus");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandChange(Command)
	
	// Pass data to server
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "endForm"              , "send"));
	QueryParameters.Add(New Structure("Name, Value", "freePackagesED"       , FreePackages));
	QueryParameters.Add(New Structure("Name, Value", "unallocatedPackagesED", Unallocated));
	QueryParameters.Add(New Structure("Name, Value",
		"enddatetarifED",
		Format(EndDate, "DF=""yyyy-MM-dd HH:mm:cc""")));
	QueryParameters.Add(New Structure("Name, Value",
		"begindatetarifED",
		Format(StartDate, "DF=""yyyy-MM-dd HH:mm:cc""")));
	
	ChangeButtonIsPressed = True;
	Modified   = False;
	
	// Send parameters to server
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext, ThisObject, QueryParameters);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Function of receiving date from a
// format row with date passed from server
// 
// Parameters
// DateRow - String with a date passed from server
//
// Returns - Date
//
&AtServer
Function GetDateFromDateFromServerRow(DateRow) Export
	
	If IsBlankString(DateRow) Then
		variabDate = Date(1,1,1);
	Else
		Try
			variabDate = Date(StrReplace
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
			variabDate = Date(1,1,1);
		EndTry;
	EndIf;
	
	Return variabDate;
	
EndFunction

// Procedure of changing appearance of the form kind depending on status
//
&AtServer
Procedure ProcessFormStatus()
	
	If Not ValueIsFilled(EDRequestStatus) OR EDRequestStatus = "none" Then
		// New application
		Items.NewApplicationPage.Visible   = True;
		Items.PageNotReviewed.Visible = False;
		Items.PageProcessed.Visible    = False;
		Items.PageRejected.Visible     = False;
		
		Items.StatusPanel.CurrentPage = Items.NewApplicationPage;
		Items.CommandChange.Visible     = True;
		ReadOnly                         = False;
		
	ElsIf EDRequestStatus = "notconsidered" Then
		// Not processed
		Items.NewApplicationPage.Visible   = False;
		Items.PageNotReviewed.Visible = True;
		Items.PageProcessed.Visible    = False;
		Items.PageRejected.Visible     = False;
		
		Items.StatusPanel.CurrentPage   = Items.PageNotReviewed;
		Items.CommandChange.Visible       = False;
		Items.CloseForm.DefaultButton  = True;
		ReadOnly                           = True;
		
	ElsIf EDRequestStatus = "rejected" Then
		// Rejected
		Items.NewApplicationPage.Visible   = False;
		Items.PageNotReviewed.Visible = False;
		Items.PageProcessed.Visible    = False;
		Items.PageRejected.Visible     = True;
		
		Items.StatusPanel.CurrentPage = Items.PageRejected;
		Items.CommandChange.Visible     = False;
		ReadOnly                         = True;
		
	ElsIf EDRequestStatus = "obtained" Then
		// Processed successfully
		Items.NewApplicationPage.Visible   = False;
		Items.PageNotReviewed.Visible = False;
		Items.PageProcessed.Visible    = True;
		Items.PageRejected.Visible     = False;
		
		Items.StatusPanel.CurrentPage = Items.PageProcessed;
		Items.CommandChange.Visible     = False;
		ReadOnly                         = True;
		
	EndIf;
	
EndProcedure

// Procedure of setting a hyperlink text for an update
//
&AtClient
Procedure SetLabelOnStatusUpdateHyperlink()
	
	HeaderText = NStr("en='Check execution of an application (%1 sec. left)';ru='Проверить выполнение заявки (осталось %1 сек.)'");
	HeaderText = StrReplace(HeaderText, "%1", String(TimeoutSeconds));
	Items.LabelRefresh.Title = HeaderText;
	
EndProcedure

// Handler of waiting for
// update of application status Runs in 1 sec
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
Procedure OnAnswerQuestionAboutClosingModifiedForm(QuestionResult, AdditParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Function MessageParametersToTechicalSupport()
	
	Result = New Structure;
	Result.Insert("Subject", NStr("en='1C-Taxcom. Change tariff.';ru='1C-Taxcom. Change tariff.'"));
	Result.Insert("Whom", "1c-taxcom@1c.ru");
	
	MessageText = NStr("en='Dear sir or madam,
		|I can not change tariff of work 
		|with ED exchange operator. 
		|Would you help me to solve the problem. 
		|
		|Login: %1. 
		|
		|%2 
		|
		|TechnicalParameters% 
		|----------------------------------------------- 
		|Sincerely, .';ru='Здравствуйте!
		|У меня не получается изменить тариф
		|работы с оператором обмена ЭД.
		|Прошу помочь разобраться с проблемой.
		|
		|Логин: %1.
		|
		|%2
		|
		|%ТехническиеПараметры%
		|-----------------------------------------------
		|С уважением, .'");
	
	UserLogin = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"login");
	
	MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
		MessageText,
		UserLogin,
		Connection1CTaxcomClient.TechnicalEDFParametersText(InteractionContext));
	
	Result.Insert("MessageText", MessageText);
	Result.Insert("ConditionalRecipientName",
		InteractionContext.COPContext.MainParameters.LaunchLocation);
	
	Return Result;
	
EndFunction

#EndRegion














