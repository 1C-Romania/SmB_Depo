////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	UserID = Users.CurrentUser().ServiceUserID;
	IdeaIdentifier = Parameters.IdeaIdentifier;
	CurrentCommentsPage = Parameters.CurrentCommentsPage;
	
	FillInIdea();
	
	InformationCenterServer.SetIdeaViewSign(New UUID(IdeaIdentifier));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CommentToIdeaAdded" Or EventName = "DeleteCommentToIdea" Then 
		RediscoverThisFormWithParameters();
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure AnswerClick(Item)
	
	CommentNumber = GetCommentNumberByName(Item.Name);
	CommentIdentifier = Comments.Get(CommentNumber - 1).ID;
	
	FormParameters = New Structure;
	FormParameters.Insert("IdeaIdentifier", IdeaIdentifier);
	FormParameters.Insert("CommentIdentifier", CommentIdentifier);
	OpenForm("DataProcessor.InformationCenter.Form.ResponseOnCommentToIdea", FormParameters);
	
EndProcedure

&AtClient
Procedure DeleteClick(Item)
	
	NotifyDescription = New NotifyDescription("DeleteCommentAlert", ThisObject, Item.Name);
	
	ShowQueryBox(NOTifyDescription, NStr("en='Delete the comment?';ru='Удалить Ваш комментарий?'"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure ButtonToLeftClick(Item)
	
	CurrentCommentsPage = CurrentCommentsPage - 1;
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure ButtonToRightClick(Item)
	
	CurrentCommentsPage = CurrentCommentsPage + 1;
	RediscoverThisFormWithParameters();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure minus(Command)
	
	VoteForIdea(-1);
	Notify("VotedForIdea");
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure PLUS(Command)
	
	VoteForIdea(1);
	Notify("VotedForIdea");
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure AddComment(Command)
	
	If IsBlankString(TextOfComment) Then 
		Raise NStr("en='The comment field should be filled in';ru='Поле комментарий должно быть заполнено'");
	EndIf;
	AddServerComment();
	Notify("CommentToIdeaAdded");
	
	ShowUserNotification("en = 'Comment is added'");
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure DeleteCommentAlert(Response, ItemName) Export
	
	If Response = DialogReturnCode.No Then 
		Return;
	EndIf;
	
	CommentNumber = GetCommentNumberByName(ItemName);
	CommentIdentifier = Comments.Get(CommentNumber - 1).ID;
	DeleteComment(CommentIdentifier);
	Notify("DeleteCommentToIdea");
	
	ShowUserNotification("en = 'Comment is deleted'");
	
EndProcedure

&AtServer
Procedure FillInIdea()
	
	DataByIdea = GetDataByIdea();
	GeneratePage(DataByIdea);
	
EndProcedure

&AtServer
Function GetDataByIdea()
	
	WSProxy = InformationCenterServer.GetIdeasCenterProxy();
	Return WSProxy.getIdea(IdeaIdentifier, String(UserID), CurrentCommentsPage, InformationCenterServer.CommentsQuantityToIdeaOnPage());
	
EndFunction

&AtServer
Procedure GeneratePage(Val DataByIdea)
	
	IdeaPresentation = DataByIdea.Idea;
	
	// Display idea title
	Title = IdeaPresentation.Name;
	
	// Display idea preheader
	Items.Preheader.Title = InformationCenterServer.GenerateIdeaPreheader(IdeaPresentation);
	Items.Subject.Title = IdeaPresentation.Subject;
	
	// Display developer comment
	Items.DeveloperComment.Visible = Not IsBlankString(IdeaPresentation.developerComment);
	Items.DeveloperComment.Title = IdeaPresentation.developerComment;
	DeveloperComment = IdeaPresentation.developerComment;
	
	// Title display
	If IdeaPresentation.Status = "plan" Then 
		Items.OnVote_1.Visible = False;
		DisplayPlannedIdea(IdeaPresentation);
	ElsIf IdeaPresentation.Status = "voiting" Then
		Items.OnVote_1.Visible = True;
		DisplayIdeaOnVote(IdeaPresentation);
	ElsIf IdeaPresentation.Status = "deviation" Then 
		Items.OnVote_1.Visible = False;
		DisplayRejectedIdea(IdeaPresentation);
	ElsIf IdeaPresentation.Status = "realization" Then 
		Items.OnVote_1.Visible = False;
		DisplayImplementedIdea(IdeaPresentation);
	ElsIf IdeaPresentation.Status = "consideration" Then 
		Items.OnVote_1.Visible = False;
		DisplayAddedIdea(IdeaPresentation);
	EndIf;
	
	// Content display
	DisplayContent(IdeaPresentation);
	
	ListOfComments = DataByIdea.CommentsList;
	// Comments display
	For Iteration = 1 To InformationCenterServer.CommentsQuantityToIdeaOnPage() Do
		
		If ListOfComments.Count() >= Iteration Then 
			CommentPresentation = ListOfComments.Get(Iteration - 1);
			NewComment = Comments.Add();
			NewComment.ID = CommentPresentation.Id;
		Else
			Items["CommentPages_" + Iteration].CurrentPage = Items["EmptyCommentPage_" + Iteration];
			Continue;
		EndIf;
		
		DisplayComment(CommentPresentation, Iteration);
		
	EndDo;
	
	// Footer display
	HasPagesBefore = ?(CurrentCommentsPage > 1, True, False);
	HasPageAfter = ?(ListOfComments.Count() > InformationCenterServer.CommentsQuantityToIdeaOnPage(), True, False);
	
	Items.PageNumber.Title = CurrentCommentsPage;
	Items.ButtonToLeft.Hyperlink = HasPagesBefore;
	Items.ButtonToLeft.Picture = ?(HasPagesBefore, PictureLib.GoToLeftActive, PictureLib.GoToLeftNotActive);
	Items.PageNumber.Title = CurrentCommentsPage;
	Items.ButtonToRight.Hyperlink = HasPageAfter;
	Items.ButtonToRight.Picture = ?(HasPageAfter, PictureLib.GoToRightActive, PictureLib.GoToRightNotActive);
	
EndProcedure

&AtServer
Procedure DisplayPlannedIdea(Val IdeaPresentation)
	
	Items.Idea_1.CurrentPage = Items.Planned_1;
	Items.AdditionalParameter.Title = InformationCenterServer.GenerateImplementationDateTitle(IdeaPresentation);
	
EndProcedure

&AtServer
Procedure DisplayIdeaOnVote(Val IdeaPresentation)
	
	Items.Idea_1.CurrentPage = Items.OnVote_1;
	
	If IdeaPresentation.Vote > 0 Then 
		Items.CommandPagesOnVote_1.CurrentPage = Items.PageVoteMinus_1;
		Items.OnMinus_Rating_1.Title = IdeaPresentation.Rating;
	ElsIf IdeaPresentation.Vote < 0 Then
		Items.CommandPagesOnVote_1.CurrentPage = Items.PageVotePlus_1;
		Items.OnPlus_Rating_1.Title = IdeaPresentation.Rating;
	Else
		Items.CommandPagesOnVote_1.CurrentPage = Items.PageWithoutVote_1;
		Items.WithoutVote_Rating_1.Title = IdeaPresentation.Rating;
	EndIf;
	
	Items.AdditionalParameter.Visible = False;
	
EndProcedure

&AtServer
Procedure DisplayRejectedIdea(Val IdeaPresentation)
	
	Items.Idea_1.CurrentPage = Items.Rejected_1;
	Items.AdditionalParameter.Title = InformationCenterServer.GenerateRejectionDate(IdeaPresentation);
	
EndProcedure

&AtServer
Procedure DisplayImplementedIdea(Val IdeaPresentation)
	
	Items.Idea_1.CurrentPage = Items.Realized_1;
	Items.AdditionalParameter.Title = InformationCenterServer.GenerateImplementationDate(IdeaPresentation);
	
EndProcedure

&AtServer
Procedure DisplayAddedIdea(Val IdeaPresentation)
	
	Items.Idea_1.CurrentPage = Items.Added_1;
	Items.AdditionalParameter.Visible = False;
	
EndProcedure

&AtServer
Procedure DisplayContent(Val IdeaPresentation)
	
	HTMLText = IdeaPresentation.HTMLText;
	
	// Place pictures in the temporary storage
	For Each DD IN IdeaPresentation.Attachments Do 
		Picture = New Picture(DD.Data);
		StorageAddress = PutToTempStorage(Picture);
		HTMLText = StrReplace(HTMLText, DD.Name, StorageAddress);
	EndDo;
	
	Content = HTMLText;
	
EndProcedure

&AtServer
Procedure DisplayComment(Val CommentPresentation, Val Iteration)
	
	Items["CommentPages_" + Iteration].CurrentPage = Items["CommentPage_" + Iteration];
	Items["CommentTitle_" + Iteration].Title = InformationCenterServer.GenerateCommentPreheader(CommentPresentation);
	Items["CommentTitle_" + Iteration].TextColor = ?(CommentPresentation.IsSupport, New Color(0, 128, 0), New Color(153, 153, 153));
	
	CurrentUserComment = (CommentPresentation.UserId = String(UserID));
	Items["PictureAnswer_" + Iteration].Visible = ?(CurrentUserComment, False, True);
	Items["Answer_" + Iteration].Visible = ?(CurrentUserComment, False, True);
	
	Items["PictureDelete_" + Iteration].Visible = ?(CurrentUserComment, True, False);
	Items["Delete_" + Iteration].Visible = ?(CurrentUserComment, True, False);
	
	AddToText = "";
	If CommentPresentation.MainIdeaComment <> Undefined Then 
		UserTitle = CommentPresentation.MainIdeaComment.UserName;
		AddToText = UserTitle + ", ";
	EndIf;
	Items["Comment" + Iteration].Title = AddToText + CommentPresentation.Text;
	Items["Comment" + Iteration].ToolTip = CommentPresentation.Text;
	
EndProcedure

&AtClient
Procedure RediscoverThisFormWithParameters()
	
	Close();
	FormParameters = New Structure;
	FormParameters.Insert("IdeaIdentifier", IdeaIdentifier);
	FormParameters.Insert("CurrentCommentsPage", CurrentCommentsPage);
	OpenForm("DataProcessor.InformationCenter.Form.Idea", FormParameters);
	
EndProcedure

&AtServer
Procedure VoteForIdea(Val Voice)
	
	Try
		WSProxy = InformationCenterServer.GetIdeasCenterProxy();
		InformationCenterServer.VoteForIdea(WSProxy, String(UserID), IdeaIdentifier, Voice);
	Except
		ErrorText = BriefErrorDescription(ErrorInfo());
		WriteLogEvent(InformationCenterServer.GetEventNameForEventLogMonitor(), 
		                         EventLogLevel.Error,
		                         ,
		                         ,ErrorText);
		OutputText = InformationCenterServer.ErrorInformationOutputTextInIdeasCenter();
		Raise OutputText;
	EndTry;
	
EndProcedure

&AtClient
Function GetCommentNumberByName(Val ItemName)
	
	ItemArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ItemName, "_");
	ItemCount = ItemArray.Count();
	If ItemCount = 0 Then 
		Return 0;
	EndIf;
	
	Try
		GetCommentNumberByName = Number(ItemArray.Get(ItemCount - 1));
	Except
		GetCommentNumberByName = 0;
	EndTry;
	
	Return GetCommentNumberByName;
	
EndFunction

&AtServer
Procedure AddServerComment()
	
	Try
		WSProxy = InformationCenterServer.GetIdeasCenterProxy();
		WSProxy.addIdeaComment(IdeaIdentifier, String(UserID), "", TextOfComment);
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
Procedure DeleteComment(Val CommentIdentifier)
	
	Try
		WSProxy = InformationCenterServer.GetIdeasCenterProxy();
		WSProxy.deleteIdeaComment(CommentIdentifier);
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
