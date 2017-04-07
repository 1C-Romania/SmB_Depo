////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SupportRequestID = Parameters.SupportRequestID;
	UserID = Users.CurrentUser().ServiceUserID;
	CurrentPage = 1;
	Reviewed = False;
	
	FillTreatmentContent();
	FillCorrespondenceByTreatment();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SendingMessageToSupportService" Or EventName = "InteractionOnContactSeen" Then 
		AttachIdleHandler("FillCorrespondenceByTreatmentClient", 0.1, True);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure InteractionsListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	
	InformationCenterClient.OpenInteractionToSupport(SupportRequestID, CurrentData.ID, CurrentData.Type, CurrentData.Incoming, CurrentData.Seen);
	
EndProcedure

&AtClient
Procedure LeftButtonClick(Item)
	
	CurrentPage = CurrentPage - 1;
	FillCorrespondenceByTreatment();
	
EndProcedure

&AtClient
Procedure RightButtonClick(Item)
	
	CurrentPage = CurrentPage + 1;
	FillCorrespondenceByTreatment();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure AddComment(Command)
	
	InformationCenterClient.OpenFormOpeningMessagesToSupport(False, SupportRequestID);
	
EndProcedure

&AtClient
Procedure Reviewed(Command)
	
	ItIsViewedAtServer();
	
	If Reviewed Then 
		Notify("InteractionOnContactSeen");
	EndIf;
	
	Reviewed = False;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillTreatmentContent()
	
	Try
		DataByTreatment = GetDataByTreatment();
		FillContent(DataByTreatment);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(InformationCenterServer.GetEventNameForEventLogMonitor(), 
		                         EventLogLevel.Error,
		                         ,
		                         ,
		                         ErrorText);
		OutputText = InformationCenterServer.ErrorInformationTextOutputInSupport();
		Raise OutputText;
	EndTry;
	
EndProcedure

&AtServer
Function GetDataByTreatment()
	
	WSProxy = InformationCenterServer.GetProxyServicesSupport();
	
	Result = WSProxy.getIncident(String(UserID), String(SupportRequestID));
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillContent(DataByTreatment)
	
	ThisForm.Title = DataByTreatment.Name + " (" + DataByTreatment.Number + ")";
	
EndProcedure

&AtClient
Procedure FillCorrespondenceByTreatmentClient()
	
	FillCorrespondenceByTreatment();
	
EndProcedure

&AtServer
Procedure FillCorrespondenceByTreatment()
	
	Try
		DataByCorrespondence = GetDataByCorrespondence();
		FillCorrespondence(DataByCorrespondence);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(InformationCenterServer.GetEventNameForEventLogMonitor(), 
		                         EventLogLevel.Error,
		                         ,
		                         ,
		                         ErrorText);
		OutputText = InformationCenterServer.ErrorInformationTextOutputInSupport();
		Raise OutputText;
	EndTry;
	
EndProcedure

&AtServer
Function GetDataByCorrespondence()
	
	WSProxy = InformationCenterServer.GetProxyServicesSupport();
	
	Result = WSProxy.getInteractions(String(UserID), String(SupportRequestID), CurrentPage);
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillCorrespondence(DataByCorrespondence)
	
	InteractionsList.Clear();
	
	For Each InteractionItem IN DataByCorrespondence.Interactions Do 
		NewInteraction = InteractionsList.Add();
		NewInteraction.ID = New UUID(InteractionItem.Id);
		NewInteraction.Subject = InteractionItem.Name;
		NewInteraction.Definition = ?(IsBlankString(InteractionItem.Description), NStr("en='<Without text>';ru='<Без текста>'"), InteractionItem.Description);
		NewInteraction.Date = InteractionItem.Date;
		NewInteraction.PictureNumber = InformationCenterServer.PictureNumberByInteraction(InteractionItem.Type, InteractionItem.Incoming);
		NewInteraction.AttachmentPicture = ?(InteractionItem.IsFiles, PictureLib.PaperClip, Undefined);
		NewInteraction.ExplanationToPicture = ?(InteractionItem.Incoming, NStr("en='inc.';ru='вкл.'"), NStr("en='Source.';ru='Источник.'"));
		NewInteraction.Incoming = InteractionItem.Incoming;
		NewInteraction.Type = InteractionItem.Type;
		NewInteraction.Seen = InteractionItem.Viewed;
	EndDo;
	
	FillFooter(DataByCorrespondence);
	
EndProcedure

&AtServer
Procedure FillFooter(DataByCorrespondence)
	
	HasPagesBefore = (CurrentPage > 1);
	HasPageAfter = DataByCorrespondence.IsStill;
	
	Items.LeftButton.Hyperlink = HasPagesBefore;
	Items.LeftButton.Picture = ?(HasPagesBefore, PictureLib.GoToLeftActive, PictureLib.GoToLeftNotActive);
	Items.RightButton.Picture = ?(HasPageAfter, PictureLib.GoToRightActive, PictureLib.GoToRightNotActive);
	Items.RightButton.Hyperlink = HasPageAfter;
	Items.CurrentPage.Title = CurrentPage;
	
EndProcedure

&AtServer
Procedure ItIsViewedAtServer()
	
	WSProxy = InformationCenterServer.GetProxyServicesSupport();
	
	Factory = WSProxy.XDTOFactory;
	
	InteractionsListType = Factory.Type("http://www.1c.ru/1cFresh/InformationCenter/SupportServiceData/1.0.0.1", "ListInteraction");
	InteractionsListXDTO = Factory.Create(InteractionsListType);
	
	RowArray = Items.InteractionsList.SelectedRows;
	For Each ArrayElement IN RowArray Do 
		FoundString = InteractionsList.FindByID(ArrayElement);
		If FoundString = Undefined Then 
			Continue;
		EndIf;
		
		If FoundString.Seen Then 
			Continue;
		EndIf;
		
		Reviewed = True;
		
		InteractionXDTO = GenerateInteractionXDTO(FoundString, Factory);
		InteractionsListXDTO.Interactions.Add(InteractionXDTO);
		
	EndDo;
	
	WSProxy.setInteractionsViewed(String(UserID), InteractionsListXDTO);
	
EndProcedure

&AtServer
Function GenerateInteractionXDTO(FoundString, Factory)
	
	TypeInteractions = Factory.Type("http://www.1c.ru/1cFresh/InformationCenter/SupportServiceData/1.0.0.1", "Interaction");
	Interaction = Factory.Create(TypeInteractions);
	
	Interaction.Id = String(FoundString.ID);
	Interaction.Type = FoundString.Type;
	Interaction.Incoming = FoundString.Incoming;
	
	Return Interaction;
	
EndFunction







