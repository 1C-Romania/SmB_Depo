
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	
	Items.LoginLabel.Title = NStr("en='Login:';ru='Авторизоваться:'") + " " + Parameters.login;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi Then
		Items.GroupInformation.Representation = UsualGroupRepresentation.None;
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
			QuestionText = NStr("en='Data was changed. Close form without saving data?';ru='Данные изменены. Закрыть форму без сохранени данных?'");
			NotifyDescription = New NotifyDescription("OnAnswerQuestionAboutClosingModifiedForm",
				ThisObject);
			
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		Else
			
			OnlineUserSupportClient.EndBusinessProcess(InteractionContext);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure LabelLogoutClick(Item)
	
	OnlineUserSupportClient.HandleUserExit(InteractionContext, ThisObject);
	
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
Procedure CommandOK(Command)
	
	If Not IsBlankString(ExchangeParticipantUUID) Then
		
		Notify("NotificationOfReceiptOfParticipantsUniqueIdEdExchange",
			ExchangeParticipantUUID);
		
		ThisObject.Modified = False;
		
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

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
	Result.Insert("Subject",
		NStr("en='1C-Taxcom. Enter a unique identifier of ED exchange participant manually';ru='1С-Такском. Ввод уникального идентификатора участника обмена ЭД вручную.'"));
	Result.Insert("Whom", "1c-taxcom@1c.ru");
	
	MessageText = NStr("en='Hello! I can not enter a unique identifier of ED participant manually. Would you help me to solve the problem? Login: %1. %2 %TechnicalParameters% ----------------------------------------------- Sincerely, .';ru='Здравствуйте!"
"У меня не получается ввести уникальный идентификатор участника ЭД вручную."
""
"Прошу помочь разобраться с проблемой."
""
"Логин: %1."
""
"%2"
""
"%ТехническиеПараметры%"
"-----------------------------------------------"
"С уважением, .'");
	
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
