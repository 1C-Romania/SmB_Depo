////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	AvailableSubjects.Load(Parameters.AvailableSubjects.Unload());
	Items.Subject.ChoiceList.LoadValues(AvailableSubjects.Unload( , "Subject").UnloadColumn("Subject"));
	
	SetPrivilegedMode(True);
	ConfigurationSynonym = Metadata.Synonym;
	SetPrivilegedMode(True);
	
	UserID = Users.CurrentUser().ServiceUserID;
	
	FoundItem = Items.Subject.ChoiceList.FindByValue(ConfigurationSynonym);
	If FoundItem = Undefined Then 
		Subject = Items.Subject.ChoiceList.Get(0).Value;
	Else
		Subject = FoundItem.Value;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure AddIdea(Command)
	
	If IsBlankString(Description) Then 
		Raise NStr("en='The Name field should not be empty.';ru='Поле Наименование не должно быть пустым'");
	EndIf;
	
	If IsBlankString(Subject) Then 
		Raise NStr("en='The Subject field should not be empty.';ru='Поле Предмет не должно быть пустым'");
	EndIf;
	
	AddIdeaServer();
	Close();
	Notify("NewIdea");
	
	ShowUserNotification("en = 'Idea is added'");
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure AddIdeaServer()
	
	WSProxy = InformationCenterServer.GetIdeasCenterProxy();
	
	HTMLText = "";
	Attachments = New Structure;
	Content.GetHTML(HTMLText, Attachments);
	CastAttachmentsList = CastAttachmentsList(Attachments, WSProxy.XDTOFactory);
	
	Try
		WSProxy.addIdea(String(UserID), HTMLText, CastAttachmentsList, Subject, Description);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(InformationCenterServer.GetEventNameForEventLogMonitor(), 
		                         EventLogLevel.Error,
		                         ,
		                         ,ErrorText);
		OutputText = InformationCenterServer.ErrorInformationOutputTextInIdeasCenter();
		Raise OutputText;
	EndTry;
	
EndProcedure

&AtServer
Function CastAttachmentsList(Val AttachmentsList, Val XDTOWebServiceFactory)
	
	AttachmentsListType    = XDTOWebServiceFactory.Type("http://www.1c.ru/1cFresh/InformationCenter/UsersIdeas/1.0.0.1", "AttachmentList");
	AttachmentsStructureType = XDTOWebServiceFactory.Type("http://www.1c.ru/1cFresh/InformationCenter/UsersIdeas/1.0.0.1", "Attachment");
	
	AttachmentObjectsList = XDTOWebServiceFactory.Create(AttachmentsListType);
	
	If AttachmentsList.Count() = 0 Then 
		Return AttachmentObjectsList;
	EndIf;
	
	For Each Attachment in AttachmentsList Do
		
		StructureAttachments = XDTOWebServiceFactory.Create(AttachmentsStructureType);
		StructureAttachments.Name = Attachment.Key;
		StructureAttachments.Data  = Attachment.Value.GetBinaryData();
		
		AttachmentObjectsList.AttachmentElement.Add(StructureAttachments);
		
	EndDo;
	
	Return AttachmentObjectsList;
	
EndFunction








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
