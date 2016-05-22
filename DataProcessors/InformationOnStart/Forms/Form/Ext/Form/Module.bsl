#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	CurrentLineIndex = -1;
	BaseConfiguration       = StandardSubsystemsServer.ThisIsBasicConfigurationVersion();
	ConfigurationSaaS = CommonUseReUse.DataSeparationEnabled();
	If CommonUse.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeReUse = CommonUse.CommonModule("DataExchangeReUse");
		ConfigurationSaaS = ConfigurationSaaS Or ModuleDataExchangeReUse.ThisIsOfflineWorkplace();
	EndIf;
	
	StandardPrefix = GetInfobaseURL() + "/";
	ThisIsWebClient = Find(StandardPrefix, "http://") > 0;
	If ThisIsWebClient Then
		LocaleCode = CurrentLocaleCode();
		StandardPrefix = StandardPrefix + LocaleCode + "/";
	EndIf;
	
	DataSavingRight = AccessRight("SaveUserData", Metadata);
	
	If BaseConfiguration Or Not DataSavingRight Then
		Items.ShowOnWorkStart.Visible = False;
	Else
		ShowOnWorkStart = True;
	EndIf;
	
	NoDataForDisplay = False;
	
	If Not PrepareFormData() Then
		
		NoDataForDisplay = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If NoDataForDisplay Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	If Not BaseConfiguration AND DataSavingRight Then
		SaveFlagState(ShowOnWorkStart);
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure WebContentOnClick(Item, EventData, StandardProcessing)
	If EventData.Property("href") AND ValueIsFilled(EventData.href) Then
		OpenedPageName = TrimAll(EventData.href);
		Protocol = Upper(PageLeftBeforeCharacter(OpenedPageName, ":"));
		If Protocol <> "HTTP" AND Protocol <> "HTTPS" AND Protocol <> "E1C" Then
			Return; // Not refs
		EndIf;
		
		If Find(OpenedPageName, StandardPrefix) > 0 Then
			OpenedPageName = StrReplace(OpenedPageName, StandardPrefix, "");
			If Left(OpenedPageName, 1) = "#" Then
				Return;
			EndIf;
			PageView("InternalLink", OpenedPageName);
		ElsIf Find(OpenedPageName, StrReplace(StandardPrefix, " ", "%20")) > 0 Then
			OpenedPageName = StrReplace(OpenedPageName, "%20", " ");
			OpenedPageName = StrReplace(OpenedPageName, StandardPrefix, "");
			If Left(OpenedPageName, 1) = "#" Then
				Return;
			EndIf;
			PageView("InternalLink", OpenedPageName);
		Else
			CommonUseClient.NavigateToLink(OpenedPageName);
		EndIf;
		StandardProcessing = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Forward(Command)
	PageView("Forward", Undefined);
EndProcedure

&AtClient
Procedure Back(Command)
	PageView("Back", Undefined);
EndProcedure

&AtClient
Procedure Attachable_GoToPage(Command)
	PageView("CommandFromCommandPane", Command.Name);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function PrepareFormData()
	Today = BegOfDay(CurrentSessionDate());
	DescriptionOfCurrentSection = "-";
	CurrentPopup = Undefined;
	AddedPopup = 0;
	MinimalPriority = 100;
	PagePackagesWithMinimumPriority = New Array;
	MainIsBusy = False;
	
	RegisterRecord = InformationRegisters.InformationPackagesOnLaunch.Get(New Structure("Number", 0));
	Cache = RegisterRecord.Content.Get();
	
	PagePackages.Load(Cache.PagePackages);
	If PagePackages.Count() = 0 Then
		Return False;
	EndIf;
	
	PagePackages.Sort("Section");
	For Each PagesPackage IN PagePackages Do
		// Skipping if the package does not need to be shown.
		If PagesPackage.ShowStartDate > Today
			Or PagesPackage.ShowEndDate < Today Then
			Continue;
		EndIf;
		
		PagesPackage.FormTitle = NStr("en = 'Information'");
		
		If MinimalPriority > PagesPackage.Priority Then
			MinimalPriority = PagesPackage.Priority;
			PagePackagesWithMinimumPriority = New Array;
			PagePackagesWithMinimumPriority.Add(PagesPackage);
		ElsIf MinimalPriority = PagesPackage.Priority
			AND PagePackagesWithMinimumPriority.Find(PagesPackage.TemplateName) = Undefined Then
			PagePackagesWithMinimumPriority.Add(PagesPackage);
		EndIf;
		
		If Not ValueIsFilled(PagesPackage.StartPageName) Then
			Continue;
		EndIf;
		
		If Left(PagesPackage.Section, 1) = "_" Then
			NumberPopup = Mid(PagesPackage.Section, 2);
			If NumberPopup = "0" Then
				PagesPackage.Section = "";
				If Not MainIsBusy Then
					PagesPackage.ID = "MainPage";
					MainIsBusy = True;
					Continue;
				EndIf;
				CurrentPopup = Items.WithoutPopup;
			Else
				PopupName = "Popup" + NumberPopup;
				CurrentPopup = Items.Find(PopupName);
				If CurrentPopup = Undefined Then
					Raise StrReplace(NStr("en = 'Group ""%1"" is not found'"), "%1", PopupName);
				EndIf;
				PagesPackage.Section = CurrentPopup.Title;
			EndIf;
		ElsIf DescriptionOfCurrentSection <> PagesPackage.Section Then
			DescriptionOfCurrentSection = PagesPackage.Section;
		
			ThisIsMain = (PagesPackage.Section = NStr("en = 'Main'"));
			If ThisIsMain AND Not MainIsBusy Then
				PagesPackage.ID = "MainPage";
				MainIsBusy = True;
				Continue;
			EndIf;
			
			If ThisIsMain Or PagesPackage.Section = "" Then
				CurrentPopup = Items.WithoutPopup;
			Else
				AddedPopup = AddedPopup + 1;
				PopupName = "Popup" + String(AddedPopup);
				CurrentPopup = Items.Find(PopupName);
				If CurrentPopup = Undefined Then
					CurrentPopup = Items.Add(PopupName, Type("FormGroup"), Items.TopPanel);
					CurrentPopup.Type = FormGroupType.Popup;
				EndIf;
				CurrentPopup.Title = PagesPackage.Section;
			EndIf;
		EndIf;
		
		If CurrentPopup <> Items.WithoutPopup Then
			PagesPackage.FormTitle = PagesPackage.FormTitle + ": " + PagesPackage.Section +" / "+ PagesPackage.StartPageName;
		EndIf;
		
		CommandName = "AddedItem_" + PagesPackage.ID;
		
		Command = Commands.Add(CommandName);
		Command.Action = "Attachable_GoToPage";
		Command.Title = PagesPackage.StartPageName;
		
		Button = Items.Add(CommandName, Type("FormButton"), CurrentPopup);
		Button.CommandName = CommandName;
		
	EndDo;
	
	Items.MainPage.Visible = MainIsBusy;
	
	If MinimalPriority = 100 Then
		Return False;
	EndIf;
	
	// Definition of the package for displaying.
	RandomNumberGenerator = New RandomNumberGenerator;
	LineNumber = RandomNumberGenerator.RandomNumber(1, PagePackagesWithMinimumPriority.Count());
	StarterPagesPackage = PagePackagesWithMinimumPriority[LineNumber-1];
	
	// Reading package from the register.
	PackageNumber = Cache.PreparedPackages.Get(StarterPagesPackage.TemplateName);
	If PackageNumber = Undefined Then
		PackageFiles = Undefined;
	Else
		RegisterRecord = InformationRegisters.InformationPackagesOnLaunch.Get(New Structure("Number", PackageNumber));
		PackageFiles = RegisterRecord.Content.Get();
	EndIf;
	If PackageFiles = Undefined Then
		PackageFiles = InformationOnStart.ExtractPackageFiles(PagesPackage.TemplateName);
	EndIf;
	
	// Preparation of the package for displaying.
	PlacePagesPackage(StarterPagesPackage, PackageFiles);
	
	// Displaying of the first page.
	If Not PageView("TeamFromTableAdded", StarterPagesPackage) Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServer
Function PageView(ActionType, Parameter = Undefined)
	Var PagesPackage, PageAddress, NewLineHistory, NewLineIndex;
	
	If ActionType = "InternalLink" Then
		
		OpenedPageName = Parameter;
		HistoryRow = ReviewHistory.Get(CurrentLineIndex);
		PagesPackage = PagePackages.FindByID(HistoryRow.PackageIdentifier);
		
		Search = New Structure("RelativeName", StrReplace(OpenedPageName, "\", "/"));
		
		Found = PagesPackage.WebPages.FindRows(Search);
		If Found.Count() = 0 Then
			Return False;
		EndIf;
		PageAddress = Found[0].Address;
		
	ElsIf ActionType = "Back" Or ActionType = "Forward" Then
		
		HistoryRow = ReviewHistory.Get(CurrentLineIndex);
		
		NewLineIndex = CurrentLineIndex + ?(ActionType = "Back", -1, +1);
		NewLineHistory = ReviewHistory[NewLineIndex];
		
		PagesPackage = PagePackages.FindByID(NewLineHistory.PackageIdentifier);
		PageAddress = NewLineHistory.PageAddress;
		
	ElsIf ActionType = "CommandFromCommandPane" Then
		
		CommandName = Parameter;
		Found = PagePackages.FindRows(New Structure("ID", StrReplace(CommandName, "AddedItem_", "")));
		If Found.Count() = 0 Then
			Return False;
		EndIf;
		PagesPackage = Found[0];
		
	ElsIf ActionType = "TeamFromTableAdded" Then
		
		PagesPackage = Parameter;
		
	Else
		
		Return False;
		
	EndIf;
	
	// Placement in the temporary storage.
	If PagesPackage.StartPageAddress = "" Then
		PackageFiles = InformationOnStart.ExtractPackageFiles(PagesPackage.TemplateName);
		PlacePagesPackage(PagesPackage, PackageFiles);
	EndIf;
	
	// Getting the address of page placement in the temporary storage.
	If PageAddress = Undefined Then
		PageAddress = PagesPackage.StartPageAddress;
	EndIf;
	
	// Registration in the history view.
	If NewLineHistory = Undefined Then
		
		HistoryNewRowStructure = New Structure("PackageIdentifier, PageAddress");
		HistoryNewRowStructure.PackageIdentifier = PagesPackage.GetID();
		HistoryNewRowStructure.PageAddress = PageAddress;
		
		Found = ReviewHistory.FindRows(HistoryNewRowStructure);
		For Each HistoryNewRowDouble IN Found Do
			ReviewHistory.Delete(HistoryNewRowDouble);
		EndDo;
		
		NewLineHistory = ReviewHistory.Add();
		FillPropertyValues(NewLineHistory, HistoryNewRowStructure);
		
	EndIf;
	
	If NewLineIndex = Undefined Then
		NewLineIndex = ReviewHistory.IndexOf(NewLineHistory);
	EndIf;
	
	If ActionType = "InternalLink" AND CurrentLineIndex <> -1 AND CurrentLineIndex <> NewLineIndex - 1 Then
		DifferenceOfIndexes = CurrentLineIndex - NewLineIndex;
		Shift = DifferenceOfIndexes + ?(DifferenceOfIndexes < 0, 1, 0);
		ReviewHistory.Move(NewLineIndex, Shift);
		NewLineIndex = NewLineIndex + Shift;
	EndIf;
	
	CurrentLineIndex = NewLineIndex;
	
	// Visible / Enabled
	Items.FormBack.Enabled = (CurrentLineIndex > 0);
	Items.FormNext.Enabled = (CurrentLineIndex < ReviewHistory.Count() - 1);
	
	// Setting the web content and the form header.
  //RISE Temnikov 19.11.2015 Comment +
	//WebContent = GetFromTempStorage(PageAddress);
	//Title = PagesPackage.FormTitle;
  //RISE Temnikov 19.11.2015 Comment -
	
	Return True;
EndFunction

&AtServer
Procedure PlacePagesPackage(PagesPackage, PackageFiles)
	PackageFiles.Images.Columns.Add("Address", New TypeDescription("String"));
	
	// Registration of images and references on the pages of the embedded help.
	For Each WebPage IN PackageFiles.WebPages Do
		HTMLText = WebPage.Data;
		
		// Registration of images.
		Length = StrLen(WebPage.RelativeDirectory);
		For Each Picture IN PackageFiles.Images Do
			// Placement of images in the temporary storage.
			If IsBlankString(Picture.Address) Then
				Picture.Address = PutToTempStorage(Picture.Data, UUID);
			EndIf;
			// Finding out the path to the image from the page.
			// For example in the page "/1/a.htm" path to picture "/1/2/b.png" will appear as "2/b.png".
			PathToPicture = Picture.RelativeName;
			If Length > 0 AND Left(PathToPicture, Length) = WebPage.RelativeDirectory Then
				PathToPicture = Mid(PathToPicture, Length + 1);
			EndIf;
			// Replacement of the relative paths to images to the addresses in the temporary storage.
			HTMLText = StrReplace(HTMLText, PathToPicture, Picture.Address);
		EndDo;
		
		// Replacement of the embedded relative references to the absolute for this IB.
		HTMLText = StrReplace(HTMLText, "v8config://", StandardPrefix + "e1cib/helpservice/topics/v8config/");
		
		// Registration of the embedded help hyperlinks.
		AddHyperlinkToBuiltInHelp(HTMLText, PagesPackage.WebPages);
		
		// Placement of the HTML content into the temporary storage.
		WebPageRegistration = PagesPackage.WebPages.Add();
		WebPageRegistration.RelativeName     = WebPage.RelativeName;
		WebPageRegistration.RelativeDirectory = WebPage.RelativeDirectory;
		WebPageRegistration.Address                = PutToTempStorage(HTMLText, UUID);
		
		// Registration of the start page.
		If WebPageRegistration.RelativeName = PagesPackage.StartPageFileName Then
			PagesPackage.StartPageAddress = WebPageRegistration.Address;
		EndIf;
	EndDo;
EndProcedure

&AtServerNoContext
Procedure SaveFlagState(ShowOnWorkStart)
	CommonUse.CommonSettingsStorageSave("InformationOnStart", "Show", ShowOnWorkStart);
	If Not ShowOnWorkStart Then
		DateOfNearestShow = BegOfDay(CurrentSessionDate() + 14*24*60*60);
		CommonUse.CommonSettingsStorageSave("InformationOnStart", "DateOfNearestShow", DateOfNearestShow);
	EndIf;
EndProcedure

&AtServer
Function AddHyperlinkToBuiltInHelp(HTMLText, WebPages)
	PrefixHyperlinksEmbeddedHelp = """" + StandardPrefix + "e1cib/helpservice/topics/v8config/v8cfgHelp/";
	Balance = HTMLText;
	While True Do
		PrefixPosition = Find(Balance, PrefixHyperlinksEmbeddedHelp);
		If PrefixPosition = 0 Then
			Break;
		EndIf;
		Balance = Mid(Balance, PrefixPosition + 1);
		
		PositionQuotes = Find(Balance, """");
		If PositionQuotes = 0 Then
			Break;
		EndIf;
		Hyperlink = Left(Balance, PositionQuotes - 1);
		Balance = Mid(Balance, PositionQuotes + 1);
		
		RelativeName = StrReplace(Hyperlink, StandardPrefix, "");
		Content = Hyperlink;
		
		FilePlacement = WebPages.Add();
		FilePlacement.RelativeName = RelativeName;
		FilePlacement.Address = PutToTempStorage(Content, UUID);
		FilePlacement.RelativeDirectory = "";
	EndDo;
EndFunction

&AtClientAtServerNoContext
Function PageLeftBeforeCharacter(String, Delimiter, Balance = Undefined)
	Position = Find(String, Delimiter);
	If Position = 0 Then
		StringBeforePoint = String;
		Balance = "";
	Else
		StringBeforePoint = Left(String, Position - 1);
		Balance = Mid(String, Position + StrLen(Delimiter));
	EndIf;
	Return StringBeforePoint;
EndFunction

#EndRegion
