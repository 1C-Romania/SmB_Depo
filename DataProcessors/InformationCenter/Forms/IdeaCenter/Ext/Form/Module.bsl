////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	CurrentIdeasFilter = Parameters.CurrentIdeasFilter;
	CurrentSorting = Parameters.CurrentSorting;
	CurrentPage = Parameters.CurrentPage;
	
	If Parameters.Property("SearchText") Then 
		SearchText = Parameters.SearchText;
	EndIf;
	If Parameters.Property("CurrentFilterBySubjects") Then 
		CurrentFilterBySubjects.Load(Parameters.CurrentFilterBySubjects.Unload());
	EndIf;
	
	UserID = Users.CurrentUser().ServiceUserID;
	IdeasQuantityOnPage = InformationCenterServer.IdeasQuantityOnPage();
	
	FillIdeasList();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NewIdea" Or EventName = "VotedForIdea"
		Or EventName = "CommentToIdeaAdded" Or EventName = "DeleteCommentToIdea" Then 
			RediscoverThisFormWithParameters();
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure OnVoteClick(Item)
	
	CurrentIdeasFilter = "voiting";
	CurrentSorting = "CreateDate";
	CurrentPage = 1;
	
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure PlannedClick(Item)
	
	CurrentIdeasFilter = "plan";
	CurrentSorting = "PlanMadeDate";
	CurrentPage = 1;
	CurrentFilterBySubjects.Clear();
	
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure RealizedClick(Item)
	
	CurrentIdeasFilter = "realization";
	CurrentSorting = "ClosingDate";
	CurrentPage = 1;
	
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure RejectedClick(Item)
	
	CurrentIdeasFilter = "deviation";
	CurrentSorting = "ClosingDate";
	CurrentPage = 1;
	
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure MyIdeasClick(Item)
	
	CurrentIdeasFilter = "favorites";
	CurrentSorting = "ChangingDate";
	CurrentPage = 1;
	
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure SortOnVoteOnChange(Item)
	
	If SortOnVote = "ByCreationDate" Then 
		CurrentSorting = "CreateDate";
	ElsIf SortOnVote = "ByVotesAmount" Then 
		CurrentSorting = "Rating";
	ElsIf SortOnVote = "ByCommentsQuantity" Then 
		CurrentSorting = "CommentsCount";
	EndIf;
	CurrentPage = 1;
	CurrentFilterBySubjects.Clear();
	
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure ButtonToLeftClick(Item)
	
	CurrentPage = CurrentPage - 1;
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure ButtonToRightClick(Item)
	
	CurrentPage = CurrentPage + 1;
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure SelectAllOnChange(Item)
	
	For Each FilterBySubject IN CurrentFilterBySubjects Do 
		FilterBySubject.Use = ChooseAll;
	EndDo;
	
	If ChooseAll Then 
		CurrentPage = 1;
		RediscoverThisFormWithParameters();
	Else
		ResetPage();
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterBySubjectsUseOnChange(Item)
	
	NegativeFilter = New Structure;
	NegativeFilter.Insert("Use", True);
	FoundArray = CurrentFilterBySubjects.FindRows(NegativeFilter);
	If FoundArray.Count() <> 0 Then 
		CurrentPage = 1;
		RediscoverThisFormWithParameters();
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectClick(Item)
	
	SubjectNumber = Item.Title;
	For Each Subject IN CurrentFilterBySubjects Do 
		Subject.Use = (Subject.Subject = SubjectNumber);
	EndDo;
	CurrentPage = 1;
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure ClickOnIdea(Item)
	
	IdeaNumber = GetIdeaNumberByName(Item.Name);
	IdeaIdentifier = Ideas.Get(IdeaNumber - 1).ID;
	InformationCenterClient.ShowIdea(IdeaIdentifier);
	
EndProcedure

&AtClient
Procedure CancelSearchClick(Item)
	
	Close();
	InformationCenterClient.OpenIdeasCenter();
	
EndProcedure

&AtClient
Procedure SearchTextOnChange(Item)
	
	ExecuteSearch();
	
EndProcedure



////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure PLUS(Command)
	
	IdeaNumber = GetIdeaNumberByName(CurrentItem.Name);
	IdeaIdentifier = Ideas.Get(IdeaNumber - 1).ID;
	VoteForIdea(1, IdeaIdentifier);
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure minus(Command)
	
	IdeaNumber = GetIdeaNumberByName(CurrentItem.Name);
	IdeaIdentifier = Ideas.Get(IdeaNumber - 1).ID;
	VoteForIdea(-1, IdeaIdentifier);
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure AddIdea(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("AvailableSubjects", CurrentFilterBySubjects);
	OpenForm("DataProcessor.InformationCenter.Form.NewIdea", FormParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure FindIdeas(Command)
	
	ExecuteSearch();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure ExecuteSearch()
	
	If IsBlankString(SearchText) Then 
		NStr("en = 'Text search query should not be empty.'");
	EndIf;
	
	CurrentIdeasFilter = "search";
	CurrentPage = 1;
	RediscoverThisFormWithParameters();
	
EndProcedure

&AtClient
Procedure RediscoverThisFormWithParameters()
	
	Close();
	FormParameters = New Structure;
	FormParameters.Insert("CurrentIdeasFilter", CurrentIdeasFilter);
	FormParameters.Insert("CurrentSorting", CurrentSorting);
	FormParameters.Insert("CurrentPage", CurrentPage);
	FormParameters.Insert("CurrentFilterBySubjects", CurrentFilterBySubjects);
	FormParameters.Insert("SearchText", SearchText);
	OpenForm("DataProcessor.InformationCenter.Form.IdeaCenter", FormParameters);
	
EndProcedure

&AtServer
Procedure FillIdeasList()
	
	Try
		IdeasListPresentation = GetIdeasListPresentation();
		GeneratePage(IdeasListPresentation);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(InformationCenterServer.GetEventNameForEventLogMonitor(), 
		                         EventLogLevel.Error,
		                         ,
		                         ,
		                         ErrorText);
		OutputText = InformationCenterServer.ErrorInformationOutputTextInIdeasCenter();
		Raise OutputText;
	EndTry;
	
EndProcedure

&AtServer
Function GetIdeasListPresentation()
	
	WSProxy = InformationCenterServer.GetIdeasCenterProxy();
	
	SubjectsList = GetIdeasSubjectsList(WSProxy.XDTOFactory);
	
	If CurrentIdeasFilter <> "search" Then 
		SearchText = "";
		Result = WSProxy.getIdeas(CurrentIdeasFilter, SubjectsList, CurrentSorting, CurrentPage, String(UserID), IdeasQuantityOnPage);
	Else 
		Result = WSProxy.searchIdeas(SearchText, CurrentIdeasFilter, SubjectsList, CurrentSorting, CurrentPage, String(UserID), IdeasQuantityOnPage);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function GetIdeasSubjectsList(Val XDTOWebServiceFactory)
	
	ItemsListType = XDTOWebServiceFactory.Type("http://www.1c.ru/1cFresh/InformationCenter/UsersIdeas/1.0.0.1", "SubjectFilterArray");
	SubjectsList = XDTOWebServiceFactory.Create(ItemsListType);
	
	For Each AvailableSubject IN CurrentFilterBySubjects Do 
		If AvailableSubject.Use Then
			SubjectsList.SubjectFilterElement.Add(AvailableSubject.Subject);
		EndIf;
	EndDo;
	
	Return SubjectsList;
	
EndFunction

&AtServer
Procedure VoteForIdea(Val Voice, Val IdeaIdentifier)
	
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
Function GetIdeaNumberByName(Val ItemName)
	
	ItemArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ItemName, "_");
	ItemCount = ItemArray.Count();
	If ItemCount = 0 Then 
		Return 0;
	EndIf;
	
	Try
		IdeaNumber = Number(ItemArray.Get(ItemCount - 1));
	Except
		IdeaNumber = 0;
	EndTry;
	
	Return IdeaNumber;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Generate page

&AtServer
Procedure ResetPage()
	
	For Iteration = 1 To InformationCenterServer.IdeasQuantityOnPage() Do 
		Items["Idea_" + Iteration].CurrentPage = Items["EmptyIdea_" + Iteration];
	EndDo;
	
	Items.ButtonToLeft.Picture = PictureLib.GoToLeftNotActive;
	Items.ButtonToRight.Picture = PictureLib.GoToRightNotActive;
	
	Items.ButtonToLeft.Hyperlink = False;
	Items.PageNumber.Title = 1;
	Items.ButtonToRight.Hyperlink = False;
	
EndProcedure

&AtServer
Procedure GeneratePage(Val IdeasListPresentation)
	
	// Display ideas filter
	DisplayIdeasFilter();
	
	// Display ideas sorting
	DisplayIdeasSorting();
	
	// Display ideas list
	Ideas.Clear();
	IdeasList = IdeasListPresentation.IdeasList;
	For Iteration = 1 To InformationCenterServer.IdeasQuantityOnPage() Do 
		
		If IdeasList.Count() >= Iteration Then 
			IdeaPresentation = IdeasList.Get(Iteration - 1);
			NewIdea = Ideas.Add();
			NewIdea.ID = IdeaPresentation.Id;
		Else
			Items["Idea_" + Iteration].CurrentPage = Items["EmptyIdea_" + Iteration];
			Continue;
		EndIf;
		
		Items["Preheader_" + Iteration].Title = InformationCenterServer.GenerateIdeaPreheader(IdeaPresentation);
		Items["Title_" + Iteration].Title = IdeaPresentation.Name;
		Items["Text_" + Iteration].Title = IdeaPresentation.Text;
		Items["Comments_" + Iteration].Title = InformationCenterServer.GenerateCommentsTitle(IdeaPresentation);
		Items["Subject_" + Iteration].Title = IdeaPresentation.Subject;
		
		If IdeaPresentation.Status = "plan" Then 
			DisplayPlannedIdea(IdeaPresentation, Iteration);
		ElsIf IdeaPresentation.Status = "voiting" Then
			DisplayIdeaOnVote(IdeaPresentation, Iteration);
		ElsIf IdeaPresentation.Status = "deviation" Then 
			DisplayRejectedIdea(IdeaPresentation, Iteration);
		ElsIf IdeaPresentation.Status = "realization" Then 
			DisplayImplementedIdea(IdeaPresentation, Iteration);
		ElsIf IdeaPresentation.Status = "consideration" Then 
			DisplayAddedIdea(IdeaPresentation, Iteration);
		EndIf;
		
	EndDo;
	
	// Footer display
	DisplayFooter(IdeasList.Count());
	
	// Display filter by ideas parameter
	DisplayFilterByIdeasSubjects(IdeasListPresentation.SubjectsList);
	
EndProcedure

&AtServer
Procedure DisplayIdeasFilter()
	
	If CurrentIdeasFilter = "voiting" Then 
		Items.FiltersByStatus.CurrentPage = Items.FilterStatus_OnVote;
	ElsIf CurrentIdeasFilter = "plan" Then 
		Items.FiltersByStatus.CurrentPage = Items.FilterStatus_Planned;
	ElsIf CurrentIdeasFilter = "deviation" Then 
		Items.FiltersByStatus.CurrentPage = Items.FilterStatus_Rejected;
	ElsIf CurrentIdeasFilter = "realization" Then 
		Items.FiltersByStatus.CurrentPage = Items.FilterStatus_Realized;
	ElsIf CurrentIdeasFilter = "favorites" Then 
		Items.FiltersByStatus.CurrentPage = Items.FilterStatus_MyIdeas;
	ElsIf CurrentIdeasFilter = "search" Then 
		Items.FiltersByStatus.CurrentPage = Items.FilterStatus_Search;
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayIdeasSorting()
	
	IdeasFilterOnVote = (CurrentIdeasFilter = "voiting");
	Items.SortOnVote.Visible = IdeasFilterOnVote;
	If Not IdeasFilterOnVote Then 
		Return;
	EndIf;
	
	If CurrentSorting = "CreateDate" Then 
		SortOnVote = Items.SortOnVote.ChoiceList.FindByValue("ByCreationDate").Value
	ElsIf CurrentSorting = "Rating" Then 
		SortOnVote = Items.SortOnVote.ChoiceList.FindByValue("ByVotesAmount").Value
	ElsIf CurrentSorting = "CommentsCount" Then
		SortOnVote = Items.SortOnVote.ChoiceList.FindByValue("ByCommentsQuantity").Value
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayFooter(Val IdeasQuantity)
	
	HasPagesBefore = ?(CurrentPage > 1, True, False);
	HasPageAfter = ?(IdeasQuantity > InformationCenterServer.IdeasQuantityOnPage(), True, False);
	
	Items.ButtonToLeft.Hyperlink = HasPagesBefore;
	Items.ButtonToLeft.Picture = ?(HasPagesBefore, PictureLib.GoToLeftActive, PictureLib.GoToLeftNotActive);
	Items.ButtonToRight.Picture = ?(HasPageAfter, PictureLib.GoToRightActive, PictureLib.GoToRightNotActive);
	Items.PageNumber.Title = CurrentPage;
	Items.ButtonToRight.Hyperlink = HasPageAfter;
	
EndProcedure

&AtServer
Procedure DisplayFilterByIdeasSubjects(Val AvailableSublectsList)
	
	FiltersReset = False;
	
	If CurrentFilterBySubjects.Count() = 0 Then 
		FiltersReset = True;
		CurrentFilterBySubjects.Clear();
	EndIf;
	
	For Each AvailableSubject IN AvailableSublectsList Do
		Filter = New Structure("Subject", AvailableSubject );
		ItemNotFound = (CurrentFilterBySubjects.FindRows(Filter).Count() <> 0);
		If Not ItemNotFound Then 
			NewItem = CurrentFilterBySubjects.Add();
			NewItem.Subject = AvailableSubject;
			NewItem.Use = FiltersReset;
		EndIf;
	EndDo;
	
	NegativeFilter = New Structure;
	NegativeFilter.Insert("Use", False);
	FoundArray = CurrentFilterBySubjects.FindRows(NegativeFilter);
	ChooseAll = (FoundArray.Count() = 0);
	
EndProcedure

&AtServer
Procedure DisplayPlannedIdea(Val IdeaPresentation, Val Iteration)
	
	Items["Representation_" + Iteration].CurrentPage = Items["Planned_" + Iteration];
	Items["AdditionalParameter_" + Iteration].Title = InformationCenterServer.GenerateImplementationDateTitle(IdeaPresentation);
	
EndProcedure

&AtServer
Procedure DisplayIdeaOnVote(Val IdeaPresentation, Val Iteration)
	
	If IdeaPresentation.Vote > 0 Then
		Items["Representation_" + Iteration].CurrentPage = Items["PageVoteMinus_" + Iteration];
		Items["OnMinus_Rating_" + Iteration].Title = IdeaPresentation.Rating;
	ElsIf IdeaPresentation.Vote < 0 Then
		Items["Representation_" + Iteration].CurrentPage = Items["PageVotePlus_" + Iteration];
		Items["OnPlus_Rating_" + Iteration].Title = IdeaPresentation.Rating;
	Else
		Items["Representation_" + Iteration].CurrentPage =  Items["PageVoteWithoutVote_" + Iteration];
		Items["WithoutVote_Rating_" + Iteration].Title = IdeaPresentation.Rating;
	EndIf;
	
EndProcedure

&AtServer
Procedure DisplayRejectedIdea(Val IdeaPresentation, Val Iteration)
	
	Items["Representation_" + Iteration].CurrentPage = Items["Rejected_" + Iteration];
	Items["AdditionalParameter_" + Iteration].Title = InformationCenterServer.GenerateRejectionDate(IdeaPresentation);

EndProcedure

&AtServer
Procedure DisplayImplementedIdea(Val IdeaPresentation, Val Iteration)
	
	Items["Representation_" + Iteration].CurrentPage = Items["Realized_" + Iteration];
	Items["AdditionalParameter_" + Iteration].Title = InformationCenterServer.GenerateImplementationDate(IdeaPresentation);
	
EndProcedure

&AtServer
Procedure DisplayAddedIdea(Val IdeaPresentation, Val Iteration)
	
	Items["Representation_" + Iteration].CurrentPage = Items["Added_" + Iteration];
	Items["AdditionalParameter_" + Iteration].Title = "";
	
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
