#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	QuickAccessPicture = PictureLib.QuickAccess;
	HiddenVariantsColour = StyleColors.HiddenReportOptionColor;
	VisibleVariantsColour = StyleColors.VisibleReportOptionColor;
	ColorIlluminationFoundWords = WebColors.Yellow;
	ColorTips = StyleColors.ExplanationText;
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.CommandBar.Width = 25;
		Items.SearchString.Width = 35;
		ReportVariantsGroupsColour = StyleColors.ReportsVariantsGroupColor82;
		ImportantGroupFont = New Font("MS Shell Dlg", 10, True, False, False, False, 100);
		CommonGroupFont = New Font("MS Shell Dlg", 8, True, False, False, False, 100);
		SectionFont = New Font("MS Shell Dlg", 12, True, False, False, False, 100);
		ImportantInscriptionFont = New Font(, , True);
	Else // Taxi.
		ReportVariantsGroupsColour = StyleColors.ReportsVariantsGroupColor;
		ImportantGroupFont = New Font("Arial", 12, False, False, False, False, 100);
		CommonGroupFont = New Font("Arial", 12, False, False, False, False, 90);
		SectionFont = New Font("Arial", 12, True, False, False, False, 100);
		ImportantInscriptionFont = New Font("Arial", 10, True, False, False, False, 100);
	EndIf;
	
	GlobalSettings = ReportsVariants.GlobalSettings();
	Items.SearchString.InputHint = GlobalSettings.Search.InputHint;
	
	SectionColor = ReportVariantsGroupsColour;
	
	Items.QuickAccessHeaderInscription.Font      = ImportantGroupFont;
	Items.QuickAccessHeaderInscription.TextColor = ReportVariantsGroupsColour;
	Items.SeeAlso.TitleFont      = ImportantGroupFont;
	Items.SeeAlso.TitleTextColor = ReportVariantsGroupsColour;
	
	FillInformationAboutSubsystemsAndSetTitle();
	
	AttributesSet = GetAttributes();
	For Each Attribute In AttributesSet Do
		ConstantAttributes.Add(Attribute.Name);
	EndDo;
	
	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	Items.SearchInAllSections.Visible = ValueIsFilled(SearchString);
	
	// Reading of custom setting common for all report panels.
	ImportAllSettings();
	
	If Parameters.Property("SearchString") Then
		SearchString = Parameters.SearchString;
	EndIf;
	If Parameters.Property("SearchInAllSections") Then
		SearchInAllSections = Parameters.SearchInAllSections;
	EndIf;
	
	// Filling the panel.
	RefreshReportsPanel();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	#If WebClient Then
		WebClient = True;
	#Else
		WebClient = False;
	#EndIf
	If ShowNotificationOnToolTips Then
		ShowUserNotification(
			NStr("en='New possibility';ru='Новая возможность'"),
			"e1cib/data/SettingsStorage.ReportsVariantsStorage.Form.DescriptionNewOptionForDescriptionsOutput",
			NStr("en='Output of descriptions in the report panels';ru='Вывод описаний в панелях отчетов'"),
			PictureLib.Information32
		);
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = ReportsVariantsClientServer.EventNameOptionChanging() Then
		Event = "";
		If TypeOf(Parameter) = Type("Structure") Then
			If Parameter.Property("ShowToolTips") Then
				ShowToolTips = Parameter.ShowToolTips;
				Event = "ShowToolTipsOnChange";
			EndIf;
		EndIf;
		RefreshReportsPanel(Event);
	EndIf;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	If SettingMode Then
		SaveUserSettings();
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure VariantPress(Item)
	Found = AddedVariants.FindRows(New Structure("TitleName", Item.Name));
	If Found.Count() <> 1 Then
		Return;
	EndIf;
	Variant = Found[0];
	
	OpenParameters = New Structure;
	OpenParameters.Insert("VariantKey", Variant.VariantKey);
	OpenParameters.Insert("Section",       CurrentSectionRef);
	
	Neighbors = AddedVariants.FindRows(New Structure("Subsystem", Variant.Subsystem));
	If Neighbors.Count() > 1 Then
		Found = ApplicationSubsystems.FindRows(New Structure("Ref", Variant.Subsystem));
		OpenParameters.Insert("Subsystem",              Variant.Subsystem);
		OpenParameters.Insert("SubsystemPresentation", Found[0].Presentation);
	EndIf;
	
	// Open
	If Variant.Additional Then
		
		OpenParameters.Insert("Variant",      Variant.Ref);
		OpenParameters.Insert("Report",        Variant.Report);
		ReportsVariantsClient.OpenAdditionalReportVariants(OpenParameters);
		
	ElsIf Not ValueIsFilled(Variant.ReportName) Then
		
		WarningText = StrReplace(NStr("en='Report name for option ""%1"" is not filled in.';ru='Не заполнено имя отчета для варианта ""%1"".'"), "%1", Variant.Description);
		ShowMessageBox(, WarningText);
		
	Else
		
		Uniqueness = "Report." + Variant.ReportName;
		If ValueIsFilled(Variant.VariantKey) Then
			Uniqueness = Uniqueness + "/VariantKey." + Variant.VariantKey;
		EndIf;
		
		OpenParameters.Insert("PrintParametersKey", Uniqueness);
		OpenParameters.Insert("WindowOptionsKey", Uniqueness);
		
		OpenForm("Report." + Variant.ReportName + ".Form", OpenParameters, Undefined, Uniqueness);
		
	EndIf;
EndProcedure

&AtClient
Procedure VisibleOptionsOnChange(Item)
	CheckBox = Item;
	Show = ThisObject[CheckBox.Name];
	
	TitleName = Mid(CheckBox.Name, StrLen("CheckBox_")+1);
	Item = Items.Find(TitleName);
	Found = AddedVariants.FindRows(New Structure("TitleName", TitleName));
	If Found.Count() <> 1 Or Item = Undefined Then
		Return;
	EndIf;
	Variant = Found[0];
	
	ShowHideOption(Variant, Item, Show);
EndProcedure

&AtClient
Procedure SearchStringTextEditEnd(Item, Text, ChoiceData, Parameters, StandardProcessing)
	If Not IsBlankString(Text) AND EnteredSearchStringIsTooShort(Text) Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Function EnteredSearchStringIsTooShort(Text)
	Text = TrimAll(Text);
	If StrLen(Text) < 2 Then
		ShowMessageBox(, NStr("en='Entered search string is too short.';ru='Введена слишком короткая строка поиска.'"));
		Return True;
	EndIf;
	
	ThereIsNormalWord = False;
	ArrayOfWords = ReportsVariantsClientServer.DecomposeSearchStringIntoWordsArray(Text);
	For Each Word In ArrayOfWords Do
		If StrLen(Word) >= 2 Then
			ThereIsNormalWord = True;
			Break;
		EndIf;
	EndDo;
	If Not ThereIsNormalWord Then
		ShowMessageBox(, NStr("en='Entered search words are too short.';ru='Введены слишком короткие слова для поиска.'"));
		Return True;
	EndIf;
	
	Return False;
EndFunction

&AtClient
Procedure SearchStringOnChange(Item)
	If Not IsBlankString(SearchString) AND EnteredSearchStringIsTooShort(SearchString) Then
		SearchString = "";
		CurrentItem = Items.SearchString;
		Return;
	EndIf;
	
	RefreshReportsPanel("SearchStringOnChange");
	
	If ValueIsFilled(SearchString) Then
		CurrentItem = Items.SearchString;
	EndIf;
EndProcedure

&AtClient
Procedure SearchInAllSectionsOnChange(Item)
	If ValueIsFilled(SearchString) Then
		RefreshReportsPanel("SearchInAllSectionsOnChange");
		CurrentItem = Items.RunSearch;
	Else
		CurrentItem = Items.SearchString;
	EndIf;
EndProcedure

&AtClient
Procedure SectionTitleClick(Item)
	SectionGroupName = Item.Parent.Name;
	Substrings = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(SectionGroupName, "_");
	SectionPriority = Substrings[1];
	Found = ApplicationSubsystems.FindRows(New Structure("Priority", SectionPriority));
	If Found.Count() = 0 Then
		Return;
	EndIf;
	Section = Found[0];
	
	ParametersForm = New Structure;
	ParametersForm.Insert("PathToSubsystem",      StrReplace(Section.FullName, "Subsystem.", ""));
	ParametersForm.Insert("SearchString",         SearchString);
	ParametersForm.Insert("SearchInAllSections", 0);
	
	OwnerForm     = ThisObject;
	FormUniqueness = True;
	
	OpenForm("CommonForm.ReportsPanel", ParametersForm, OwnerForm, FormUniqueness);
EndProcedure

&AtClient
Procedure ShowToolTipsOnChange(Item)
	RefreshReportsPanel("ShowToolTipsOnChange");
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Configure(Command)
	SettingMode = Not SettingMode;
	RefreshReportsPanel();
EndProcedure

&AtClient
Procedure MoveToQuickAccess(Command)
	If WebClient Then
		Item = Items.Find(Mid(Command.Name, Find(Command.Name, "_")+1));
	Else
		Item = CurrentItem;
	EndIf;
	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Found = AddedVariants.FindRows(New Structure("TitleName", Item.Name));
	If Found.Count() <> 1 Then
		Return;
	EndIf;
	Variant = Found[0];
	
	AddTakeAwayOptionFromQuickAccess(Variant, Item, True);
EndProcedure

&AtClient
Procedure RemoveFromQuickAccess(Command)
	If WebClient Then
		Item = Items.Find(Mid(Command.Name, Find(Command.Name, "_")+1));
	Else
		Item = CurrentItem;
	EndIf;
	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Found = AddedVariants.FindRows(New Structure("TitleName", Item.Name));
	If Found.Count() <> 1 Then
		Return;
	EndIf;
	Variant = Found[0];
	
	AddTakeAwayOptionFromQuickAccess(Variant, Item, False);
EndProcedure

&AtClient
Procedure Change(Command)
	If WebClient Then
		Item = Items.Find(Mid(Command.Name, Find(Command.Name, "_")+1));
	Else
		Item = CurrentItem;
	EndIf;
	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Found = AddedVariants.FindRows(New Structure("TitleName", Item.Name));
	If Found.Count() <> 1 Then
		Return;
	EndIf;
	Variant = Found[0];
	
	ReportsVariantsClient.ShowReportSettings(Variant.Ref);
EndProcedure

&AtClient
Procedure ResetSettings(Command)
	QuestionText = NStr("en='Do you want to reset the reports placement settings?';ru='Сбросить настройки расположения отчетов?'");
	Handler = New NotifyDescription("ResetSettingsEnd", ThisObject);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.No);
EndProcedure

&AtClient
Procedure AllReports(Command)
	ParametersForm = New Structure;
	If ValueIsFilled(SearchString) Then
		ParametersForm.Insert("SearchString", SearchString);
	EndIf;
	If ValueIsFilled(SearchString) AND Not SettingMode AND SearchInAllSections = 1 Then
		// Locate on the root of the tree.
		SectionRef = PredefinedValue("Catalog.MetadataObjectIDs.EmptyRef");
	Else
		SectionRef = CurrentSectionRef;
	EndIf;
	ParametersForm.Insert("SectionRef", SectionRef);
	OpenForm("Catalog.ReportsVariants.ListForm", ParametersForm, , "ReportsVariants.AllReports");
EndProcedure

&AtClient
Procedure Refresh(Command)
	RefreshReportsPanel();
EndProcedure

&AtClient
Procedure RunSearch(Command)
	RefreshReportsPanel();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure ShowHideOption(Variant, Item, Show)
	Variant.Visible = Show;
	Variant.ChangedByUser = True;
	Item.TextColor = ?(Show, VisibleVariantsColour, HiddenVariantsColour);
	ThisObject["CheckBox_"+ Variant.TitleName] = Show;
	If Variant.Important Then
		If Show Then
			Item.Font = ImportantInscriptionFont;
		Else
			Item.Font = New Font;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure AddTakeAwayOptionFromQuickAccess(Variant, Item, QuickAccess)
	If Variant.QuickAccess = QuickAccess Then
		Return;
	EndIf;
	
	// Registration of result for recording.
	Variant.QuickAccess = QuickAccess;
	Variant.ChangedByUser = True;
	
	// Related activity: if variant added to the quick access is not visible - then show it.
	If QuickAccess AND Not Variant.Visible Then
		ShowHideOption(Variant, Item, True);
	EndIf;
	
	// Visual result
	TransferQuickAccessOption(Variant.GetID(), QuickAccess);
EndProcedure

&AtClient
Procedure ResetSettingsEnd(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		ResetSettingsAndRefreshReportsPanel();
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Calling the server

&AtServer
Procedure TransferQuickAccessOption(Val OptionIdentifier, Val QuickAccess)
	Variant = AddedVariants.FindByID(OptionIdentifier);
	Item = Items.Find(Variant.TitleName);
	
	If QuickAccess Then
		Item.Font = New Font;
		GroupForTransferring = SubgroupWithLessItemsCount(Items.QuickAccess);
	ElsIf Variant.SeeAlso Then
		Item.Font = New Font;
		GroupForTransferring = SubgroupWithLessItemsCount(Items.SeeAlso);
	ElsIf Variant.WithoutGroup Then
		Item.Font = ?(Variant.Important, ImportantInscriptionFont, New Font);
		GroupForTransferring = SubgroupWithLessItemsCount(Items.WithoutGroup);
	Else
		Item.Font = ?(Variant.Important, ImportantInscriptionFont, New Font);
		Found = ApplicationSubsystems.FindRows(New Structure("Ref", Variant.Subsystem));
		Subsystem = Found[0];
		
		GroupForTransferring = Items.Find(Subsystem.ItemName + "_1");
		If GroupForTransferring = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	BeforeWhichItem = Undefined;
	If GroupForTransferring.ChildItems.Count() > 0 Then
		BeforeWhichItem = GroupForTransferring.ChildItems.Get(0);
	EndIf;
	
	Items.Move(Item.Parent, GroupForTransferring, BeforeWhichItem);
	
	If QuickAccess Then
		Items.QuickAccessToolTipWhenNotConfigured.Visible = False;
	Else
		QuickAccessOptions = AddedVariants.FindRows(New Structure("QuickAccess", True));
		If QuickAccessOptions.Count() = 0 Then
			Items.QuickAccessToolTipWhenNotConfigured.Visible = True;
		Else
			Items.QuickAccessToolTipWhenNotConfigured.Visible = False;
		EndIf;
	EndIf;
	
	FlagName = "CheckBox_" + Variant.TitleName;
	CheckBox = Items.Find(FlagName);
	FlagDisplayed = (CheckBox.Visible = True);
	If FlagDisplayed = QuickAccess Then
		CheckBox.Visible = Not QuickAccess;
	EndIf;
	
	LabelContextMenu = Item.ContextMenu;
	If LabelContextMenu <> Undefined Then
		ButtonRemove = Items.Find("RemoveFromQuickAccess_" + Variant.TitleName);
		ButtonMove = Items.Find("MoveQuickAccess_" + Variant.TitleName);
		ButtonRemove.Visible = QuickAccess;
		ButtonMove.Visible = Not QuickAccess;
	EndIf;
	
EndProcedure

&AtServer
Procedure ResetSettingsAndRefreshReportsPanel()
	SettingMode = False;
	InformationRegisters.ReportsVariantsSettings.ResetUserSettingsSection(CurrentSectionRef);
	RefreshReportsPanel();
EndProcedure

&AtServer
Procedure RefreshReportsPanel(Val Event = "")
	If Event = "" Or Event = "SearchStringOnChange" Then
		If ValueIsFilled(SearchString) Then
			ChoiceList = Items.SearchString.ChoiceList;
			ItemOfList = ChoiceList.FindByValue(SearchString);
			If ItemOfList = Undefined Then
				ChoiceList.Insert(0, SearchString);
				If ChoiceList.Count() > 10 Then
					ChoiceList.Delete(10);
				EndIf;
			Else
				IndexOf = ChoiceList.IndexOf(ItemOfList);
				If IndexOf <> 0 Then
					ChoiceList.Move(IndexOf, -IndexOf);
				EndIf;
			EndIf;
			If Event = "SearchStringOnChange" Then
				SaveThisReportsPanelSettings();
			EndIf;
		EndIf;
	ElsIf Event = "ShowToolTipsOnChange"
		Or Event = "SearchInAllSectionsOnChange" Then
		SaveAllReportsPanelsSettings();
	EndIf;
	Items.SearchInAllSections.Visible = Not SettingMode AND ValueIsFilled(SearchString);
	
	Items.ShowToolTips.Visible = SettingMode;
	Items.QuickAccessHeaderInscription.ToolTipRepresentation = ?(SettingMode, ToolTipRepresentation.Button, ToolTipRepresentation.None);
	Items.SearchResultsFromOtherGroupSections.Visible = (SearchInAllSections = 1);
	Items.Configure.Check = SettingMode;
	
	// Title.
	SetupModeSuffix = " (" + NStr("en='setting';ru='настройка'") + ")";
	SuffixOutput = (Right(Title, StrLen(SetupModeSuffix)) = SetupModeSuffix);
	If SuffixOutput <> SettingMode Then
		If SettingMode Then
			Title = Title + SetupModeSuffix;
		Else
			Title = StrReplace(Title, SetupModeSuffix, "");
		EndIf;
	EndIf;
	
	// Delete items.
	ClearFormFromAddedItems();
	
	// Delete commands
	If WebClient Then
		DeletedCommands = New Array;
		For Each Command In Commands Do
			If ConstantCommands.FindByValue(Command.Name) = Undefined Then
				DeletedCommands.Add(Command);
			EndIf;
		EndDo;
		For Each Command In DeletedCommands Do
			Commands.Delete(Command);
		EndDo;
	EndIf;
	
	// Save custom settings.
	SaveUserSettings();
	
	// Reset the last added item number.
	For Each TableRow In ApplicationSubsystems Do
		TableRow.ItemNumber = 0;
	EndDo;
	
	// Filling the reports panel
	FillReportsPanel();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure ClearFormFromAddedItems()
	DeletedItems = New Array;
	For Each Level3Item In Items.QuickAccess.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			DeletedItems.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.WithoutGroup.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			DeletedItems.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.WithGroup.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			DeletedItems.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.SeeAlso.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			DeletedItems.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level4Item In Items.SearchResultsFromOtherSections.ChildItems Do
		DeletedItems.Add(Level4Item);
	EndDo;
	For Each ElementToDelete In DeletedItems Do
		Items.Delete(ElementToDelete);
	EndDo;
EndProcedure

&AtServer
Procedure SaveUserSettings()
	If AddedVariants.Count() = 0 Then
		Return;
	EndIf;
	Filter = New Structure("ChangedByUser", True);
	
	SettingsPackage = AddedVariants.Unload(Filter, "Ref, Subsystem, Visible, QuickAccess");
	If SettingsPackage.Count() = 0 Then
		Return;
	EndIf;
	SettingsPackage.Columns.Ref.Name = "Variant";
	Dimensions = New Structure("User", Users.CurrentUser());
	Resources   = New Structure;
	InformationRegisters.ReportsVariantsSettings.WriteSettingsPackage(SettingsPackage, Dimensions, Resources, False);
EndProcedure

&AtServer
Function SubgroupWithLessItemsCount(Group)
	SubgroupMin = Undefined;
	NestedItemsMin = 0;
	For Each Subgroup In Group.ChildItems Do
		NestedItems = Subgroup.ChildItems.Count();
		If NestedItems < NestedItemsMin Or SubgroupMin = Undefined Then
			SubgroupMin          = Subgroup;
			NestedItemsMin = NestedItems;
		EndIf;
	EndDo;
	Return SubgroupMin;
EndFunction

&AtServer
Procedure FillInformationAboutSubsystemsAndSetTitle()
	TitlePredefinedByCommand = Parameters.Property("Title");
	If TitlePredefinedByCommand Then
		Title = Parameters.Title;
	EndIf;
	
	CurrentSectionFullName = "Subsystem." + StrReplace(Parameters.PathToSubsystem, ".", ".Subsystem.");
	
	AllSubsystems = ReportsVariantsReUse.CurrentUserSubsystems();
	AllSections = AllSubsystems.Rows[0].Rows;
	For Each RowSection In AllSections Do
		TableRow = ApplicationSubsystems.Add();
		FillPropertyValues(TableRow, RowSection);
		TableRow.ItemName    = StrReplace(RowSection.FullName, ".", "_");
		TableRow.ItemNumber  = 0;
		TableRow.SectionRef   = RowSection.Ref;
		
		If RowSection.FullName = CurrentSectionFullName Then
			CurrentSectionRef = RowSection.Ref;
			If TitlePredefinedByCommand Then
				RowSection.FullPresentation = Parameters.Title;
			Else
				Title = RowSection.FullPresentation;
			EndIf;
		EndIf;
		
		Found = RowSection.Rows.FindRows(New Structure("SectionRef", RowSection.Ref), True);
		For Each TreeRow In Found Do
			TableRow = ApplicationSubsystems.Add();
			FillPropertyValues(TableRow, TreeRow);
			TableRow.ItemName    = StrReplace(TableRow.FullName, ".", "_");
			TableRow.ItemNumber  = 0;
			TableRow.ParentRef = TreeRow.Parent.Ref;
			TableRow.SectionRef   = RowSection.Ref;
			
			If TreeRow.FullName = CurrentSectionFullName Then
				CurrentSectionRef = TreeRow.Ref;
				If TitlePredefinedByCommand Then
					TreeRow.FullPresentation = Parameters.Title;
				Else
					Title = TreeRow.FullPresentation;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If CurrentSectionRef = Catalogs.MetadataObjectIDs.EmptyRef() Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Section ""%1"" is not connected to the ""%2"" subsystem.See
		|ReportsVariantsPredefined module, DetermineSectionsWithReportsVariants procedure.';ru='Раздел ""%1"" не подключен к подсистеме ""%2"".См. модуль ВариантыОтчетовПереопределяемый, процедуру ОпределитьРазделыСВариантамиОтчетов.'"),
			Parameters.PathToSubsystem,
			ReportsVariantsClientServer.SubsystemDescription(Undefined));
	EndIf;
	
	PurposeUseKey = "Section_" + String(CurrentSectionRef.UUID());
EndProcedure

&AtServer
Procedure ImportAllSettings()
	CommonSettings = ReportsVariants.CommonPanelSettings();
	// WithShowNotificationsAboutToolTips, ShowToolTips, SearchInAllSections.
	FillPropertyValues(ThisObject, CommonSettings);
	
	LocalSettings = CommonUse.CommonSettingsStorageImport(
		ReportsVariantsClientServer.SubsystemFullName(),
		PurposeUseKey);
	If LocalSettings <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(LocalSettings.SearchStringChoiceList);
	EndIf;
EndProcedure

&AtServer
Procedure SaveAllReportsPanelsSettings()
	CommonSettings = New Structure;
	CommonSettings.Insert("ShowToolTips", ShowToolTips);
	CommonSettings.Insert("SearchInAllSections", SearchInAllSections);
	
	CommonUse.CommonSettingsStorageSave(
		ReportsVariantsClientServer.SubsystemFullName(),
		"ReportsPanel",
		CommonSettings);
EndProcedure

&AtServer
Procedure SaveThisReportsPanelSettings()
	LocalSettings = New Structure;
	LocalSettings.Insert("SearchStringChoiceList", Items.SearchString.ChoiceList.UnloadValues());
	
	CommonUse.CommonSettingsStorageSave(
		ReportsVariantsClientServer.SubsystemFullName(),
		PurposeUseKey,
		LocalSettings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server / Filling the reports panel.

&AtServer
Procedure FillReportsPanel()
	// Clearing information about changes in custom settings.
	AddedVariants.Clear();
	
	FillingParameters = New Structure;
	InitializeFillingParameters(FillingParameters);
	
	FindReportsVariantsForWithdrawal(FillingParameters);
	
	If SettingMode Then
		FillingParameters.ContextMenu.RemoveFromQuickAccess.Visible = True;
		FillingParameters.ContextMenu.MoveToQuickAccess.Visible = False;
	EndIf;
	
	OuputSectionVariants(FillingParameters, CurrentSectionRef);
	
	If FillingParameters.OnlyCurrentSection Then
		Items.SearchResultsFromOtherGroupSections.Visible = False;
	Else
		Items.SearchResultsFromOtherGroupSections.Visible = True;
		If FillingParameters.OtherSections.Count() = 0 Then
			Label = Items.Insert("InOtherSections", Type("FormDecoration"), Items.SearchResultsFromOtherSections);
			Label.Title = "    " + NStr("en='Reports in other sections are not found.';ru='Отчеты в других разделах не найдены.'") + Chars.LF;
			Label.Height = 2;
		EndIf;
		For Each SectionRef In FillingParameters.OtherSections Do
			OuputSectionVariants(FillingParameters, SectionRef);
		EndDo;
		If FillingParameters.DontOutput > 0 Then // Output of information text.
			LabelTitle = NStr("en='First %1 reports from other sections have been output, specify the search query.';ru='Выведены первые %1 отчетов из других разделов, уточните поисковый запрос.'");
			LabelTitle = StrReplace(LabelTitle, "%1", FillingParameters.OutputLimit);
			Label = Items.Insert("OutputLimitExceeded", Type("FormDecoration"), Items.SearchResultsFromOtherSections);
			Label.Title = LabelTitle;
			Label.Font = ImportantInscriptionFont;
			Label.Height = 2;
		EndIf;
	EndIf;
	
	If FillingParameters.AttributesToAdd.Count() > 0 Then
		// Registration of old attributes for deletion.
		AttributesToBeRemoved = New Array;
		AttributesSet = GetAttributes();
		For Each Attribute In AttributesSet Do
			If ConstantAttributes.FindByValue(Attribute.Name) = Undefined Then
				AttributesToBeRemoved.Add(Attribute.Name);
			EndIf;
		EndDo;
		// Delete old and add new attributes.
		ChangeAttributes(FillingParameters.AttributesToAdd, AttributesToBeRemoved);
		// Connection of new attributes to the data.
		For Each Attribute In FillingParameters.AttributesToAdd Do
			CheckBox = Items.Find(Attribute.Name);
			CheckBox.DataPath = Attribute.Name;
			TitleName = Mid(Attribute.Name, StrLen("CheckBox_")+1);
			Found = AddedVariants.FindRows(New Structure("TitleName", TitleName));
			If Found.Count() > 0 Then
				Variant = Found[0];
				ThisObject[Attribute.Name] = Variant.Visible;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFillingParameters(FillingParameters)
	ItemsOptionsDisplayed = 0;
	
	FillingParameters.Insert("GroupName", "");
	FillingParameters.Insert("AttributesToAdd", New Array);
	FillingParameters.Insert("AddedEmptyDecorations", 0);
	FillingParameters.Insert("OutputLimit", 20);
	FillingParameters.Insert("LeftToOutput", FillingParameters.OutputLimit);
	FillingParameters.Insert("DontOutput", 0);
	
	TemplateOptionGroups = New Structure(
		"Type,
		|HorizontalStretch, Representation,
		|Group, ShowTitle");
	TemplateOptionGroups.Type = FormGroupType.UsualGroup;
	TemplateOptionGroups.HorizontalStretch = True;
	TemplateOptionGroups.Representation = UsualGroupRepresentation.None;
	TemplateOptionGroups.Group = ChildFormItemsGroup.Horizontal;
	TemplateOptionGroups.ShowTitle = False;
	
	TemplateQuickAccessPictures = New Structure(
		"Type, Width, Height,
		|Picture, HorizontalStretch, VerticalStretch");
	TemplateQuickAccessPictures.Type = FormDecorationType.Picture;
	TemplateQuickAccessPictures.Width = 2;
	TemplateQuickAccessPictures.Height = 1;
	TemplateQuickAccessPictures.Picture = QuickAccessPicture;
	TemplateQuickAccessPictures.HorizontalStretch = False;
	TemplateQuickAccessPictures.VerticalStretch = False;
	
	TemplateIndentPictures = New Structure(
		"Type, Width,
		|Height, HorizontalStretch, VerticalStretch");
	TemplateIndentPictures.Type = FormDecorationType.Picture;
	TemplateIndentPictures.Width = 1;
	TemplateIndentPictures.Height = 1;
	TemplateIndentPictures.HorizontalStretch = False;
	TemplateIndentPictures.VerticalStretch = False;
	
	// Templates for created control items filling.
	OptionLabelTemplate = New Structure(
		"Type, Hyperlink, Height,
		|TextColor, HorizontalStretch, VerticalStretch");
	OptionLabelTemplate.Type = FormDecorationType.Label;
	OptionLabelTemplate.Hyperlink = True;
	OptionLabelTemplate.HorizontalStretch = True;
	OptionLabelTemplate.VerticalStretch = False;
	OptionLabelTemplate.Height = 1;
	OptionLabelTemplate.TextColor = VisibleVariantsColour;
	
	FillingParameters.Insert("Patterns", New Structure);
	FillingParameters.Patterns.Insert("VariantGroup", TemplateOptionGroups);
	FillingParameters.Patterns.Insert("PictureShortcuts", TemplateQuickAccessPictures);
	FillingParameters.Patterns.Insert("PictureInset", TemplateIndentPictures);
	FillingParameters.Patterns.Insert("InscriptionOptions", OptionLabelTemplate);
	
	If SettingMode Then
		FillingParameters.Insert("ContextMenu", New Structure("RemoveFromQuickAccess, MoveToQuickAccess, Change"));
		FillingParameters.ContextMenu.RemoveFromQuickAccess   = New Structure("Visible", False);
		FillingParameters.ContextMenu.MoveToQuickAccess = New Structure("Visible", False);
		FillingParameters.ContextMenu.Change                  = New Structure("Visible", True);
	EndIf;
	
	FillingParameters.Insert("ImportanceGroups", New Array);
	FillingParameters.ImportanceGroups.Add("QuickAccess");
	FillingParameters.ImportanceGroups.Add("WithoutGroup");
	FillingParameters.ImportanceGroups.Add("WithGroup");
	FillingParameters.ImportanceGroups.Add("SeeAlso");
	
	For Each GroupName In FillingParameters.ImportanceGroups Do
		FillingParameters.Insert(GroupName, New Structure("Filter, Variants, Quantity"));
	EndDo;
	
	FillingParameters.QuickAccess.Filter = New Structure("QuickAccess", True);
	FillingParameters.WithoutGroup.Filter     = New Structure("QuickAccess, WithoutGroup", False, True);
	FillingParameters.WithGroup.Filter      = New Structure("QuickAccess, WithoutGroup, SeeAlso", False, False, False);
	FillingParameters.SeeAlso.Filter       = New Structure("QuickAccess, WithoutGroup, SeeAlso", False, False, True);
	
EndProcedure

&AtServer
Procedure FindReportsVariantsForWithdrawal(FillingParameters)
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	Subsystems.Ref AS Subsystem,
	|	Subsystems.SectionRef AS SectionRef,
	|	Subsystems.Presentation,
	|	Subsystems.Priority
	|INTO ttSubsystems
	|FROM
	|	&SubsystemTable AS Subsystems
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReportsVariants.Ref,
	|	PredefinedLocation.Subsystem,
	|	PredefinedLocation.Important,
	|	PredefinedLocation.SeeAlso,
	|	CASE
	|		WHEN SubString(ReportsVariants.Definition, 1, 1) = """"
	|			THEN CAST(PredefinedLocation.Ref.Definition AS String(1000))
	|		ELSE CAST(ReportsVariants.Definition AS String(1000))
	|	END AS Definition,
	|	ReportsVariants.Description,
	|	ReportsVariants.Report,
	|	ReportsVariants.ReportType,
	|	ReportsVariants.VariantKey,
	|	ReportsVariants.Author,
	|	ReportsVariants.VisibleByDefault,
	|	ReportsVariants.Parent
	|INTO TTPredefined
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|		INNER JOIN Catalog.PredefinedReportsVariants.Placement AS PredefinedLocation
	|		ON (ReportsVariants.Ref IN (&VariantsFoundBySearch)
	|				OR PredefinedLocation.Subsystem IN (&SubsystemsFoundBySearch))
	|			AND ReportsVariants.PredefinedVariant = PredefinedLocation.Ref
	|			AND (PredefinedLocation.Subsystem IN (&SubsystemArray))
	|			AND (ReportsVariants.DeletionMark = FALSE)
	|			AND (ReportsVariants.Report IN (&UserReporting))
	|			AND (NOT PredefinedLocation.Ref IN (&DisabledApplicationOptions))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	LocationVariants.Ref,
	|	LocationVariants.Subsystem,
	|	LocationVariants.Use,
	|	LocationVariants.Important,
	|	LocationVariants.SeeAlso,
	|	CASE
	|		WHEN SubString(LocationVariants.Ref.Definition, 1, 1) = """"
	|				AND NOT LocationVariants.Ref.User
	|			THEN CAST(LocationVariants.Ref.PredefinedVariant.Definition AS String(1000))
	|		ELSE CAST(LocationVariants.Ref.Definition AS String(1000))
	|	END AS Definition,
	|	LocationVariants.Ref.ForAuthorOnly,
	|	LocationVariants.Ref.Description,
	|	LocationVariants.Ref.Report,
	|	LocationVariants.Ref.ReportType,
	|	LocationVariants.Ref.VariantKey,
	|	LocationVariants.Ref.Author,
	|	LocationVariants.Ref.Parent,
	|	LocationVariants.Ref.VisibleByDefault
	|INTO ttOptions
	|FROM
	|	Catalog.ReportsVariants.Placement AS LocationVariants
	|WHERE
	|	(LocationVariants.Ref IN (&VariantsFoundBySearch)
	|			OR LocationVariants.Subsystem IN (&SubsystemsFoundBySearch))
	|	AND (NOT LocationVariants.Ref.ForAuthorOnly
	|			OR LocationVariants.Ref.Author = &CurrentUser)
	|	AND LocationVariants.Ref.DeletionMark = FALSE
	|	AND LocationVariants.Subsystem IN(&SubsystemArray)
	|	AND LocationVariants.Ref.Report IN(&UserReporting)
	|	AND NOT LocationVariants.Ref.PredefinedVariant IN (&DisabledApplicationOptions)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ISNULL(ttOptions.Ref, TTPredefined.Ref) AS Ref,
	|	ISNULL(ttOptions.Subsystem, TTPredefined.Subsystem) AS Subsystem,
	|	ISNULL(ttOptions.Important, TTPredefined.Important) AS Important,
	|	ISNULL(ttOptions.SeeAlso, TTPredefined.SeeAlso) AS SeeAlso,
	|	ISNULL(ttOptions.Description, TTPredefined.Description) AS Description,
	|	ISNULL(ttOptions.Definition, TTPredefined.Definition) AS Definition,
	|	ISNULL(ttOptions.Author, TTPredefined.Author) AS Author,
	|	ISNULL(ttOptions.Report, TTPredefined.Report) AS Report,
	|	ISNULL(ttOptions.ReportType, TTPredefined.ReportType) AS ReportType,
	|	ISNULL(ttOptions.VariantKey, TTPredefined.VariantKey) AS VariantKey,
	|	ISNULL(ttOptions.VisibleByDefault, TTPredefined.VisibleByDefault) AS VisibleByDefault,
	|	ISNULL(ttOptions.Parent, TTPredefined.Parent) AS Parent,
	|	CASE
	|		WHEN ISNULL(ttOptions.Parent, TTPredefined.Parent) = VALUE(Catalog.ReportsVariants.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS TopLevel
	|INTO ttAllVariants
	|FROM
	|	TTPredefined AS TTPredefined
	|		Full JOIN ttOptions AS ttOptions
	|		ON TTPredefined.Ref = ttOptions.Ref
	|			AND TTPredefined.Subsystem = ttOptions.Subsystem
	|WHERE
	|	(ttOptions.Use = TRUE
	|			OR ttOptions.Use IS NULL )
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ttAllVariants.Ref,
	|	ttAllVariants.Subsystem,
	|	ttSubsystems.Presentation AS SubsystemPresentation,
	|	ttSubsystems.Priority AS SubsystemOfPriority,
	|	ttSubsystems.SectionRef AS SectionRef,
	|	CASE
	|		WHEN ttAllVariants.Subsystem = ttSubsystems.SectionRef
	|				AND ttAllVariants.SeeAlso = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS WithoutGroup,
	|	ttAllVariants.Important,
	|	ttAllVariants.SeeAlso,
	|	CASE
	|		WHEN ttAllVariants.ReportType = &TypeOptional
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Additional,
	|	ISNULL(PersonalSettings.Visible, ttAllVariants.VisibleByDefault) AS Visible,
	|	ISNULL(PersonalSettings.QuickAccess, FALSE) AS QuickAccess,
	|	CASE
	|		WHEN ttAllVariants.ReportType = &TypeInternal
	|			THEN ttAllVariants.Report.Name
	|		WHEN ttAllVariants.ReportType = &TypeOptional
	|			THEN """"
	|		ELSE SubString(CAST(ttAllVariants.Report AS String(150)), 14, 137)
	|	END AS ReportName,
	|	ttAllVariants.Description AS Description,
	|	ttAllVariants.Definition,
	|	ttAllVariants.Author,
	|	ttAllVariants.Report,
	|	ttAllVariants.ReportType,
	|	ttAllVariants.VariantKey,
	|	ttAllVariants.Parent,
	|	ttAllVariants.TopLevel AS TopLevel
	|FROM
	|	ttAllVariants AS ttAllVariants
	|		LEFT JOIN ttSubsystems AS ttSubsystems
	|		ON ttAllVariants.Subsystem = ttSubsystems.Subsystem
	|		LEFT JOIN InformationRegister.ReportsVariantsSettings AS PersonalSettings
	|		ON ttAllVariants.Subsystem = PersonalSettings.Subsystem
	|			AND ttAllVariants.Ref = PersonalSettings.Variant
	|			AND (PersonalSettings.User = &CurrentUser)
	|WHERE
	|	ISNULL(PersonalSettings.Visible, ttAllVariants.VisibleByDefault)
	|
	|ORDER BY
	|	SubsystemOfPriority,
	|	Description";
	
	OnlyCurrentSection = SettingMode Or Not ValueIsFilled(SearchString) Or SearchInAllSections = 0;
	If OnlyCurrentSection Then
		SubsystemTable = ApplicationSubsystems.Unload(New Structure("SectionRef", CurrentSectionRef));
	Else
		SubsystemTable = ApplicationSubsystems.Unload();
	EndIf;
	SubsystemArray = SubsystemTable.UnloadColumn("Ref");
	
	UseBacklight = ValueIsFilled(SearchString);
	
	SearchParameters = New Structure;
	If UseBacklight Then
		SearchParameters.Insert("SearchString", SearchString);
	EndIf;
	If OnlyCurrentSection Then
		SearchParameters.Insert("Subsystems", SubsystemArray);
	EndIf;
	SearchParameters.Insert("DeletionMark", False);
	
	SearchResult = ReportsVariants.FindReferences(SearchParameters);
	
	Query.SetParameter("SubsystemArray",      SubsystemArray);
	Query.SetParameter("SubsystemTable",     SubsystemTable);
	Query.SetParameter("SectionRef",         CurrentSectionRef);
	Query.SetParameter("CurrentUser",  Users.CurrentUser());
	Query.SetParameter("TypeInternal",        Enums.ReportsTypes.Internal);
	Query.SetParameter("TypeOptional",    Enums.ReportsTypes.Additional);
	Query.SetParameter("VariantsFoundBySearch", SearchResult.Refs);
	If UseBacklight AND SearchResult.Subsystems.Count() > 0 Then
		Query.SetParameter("SubsystemsFoundBySearch",   SearchResult.Subsystems);
		Query.SetParameter("UserReporting",           SearchParameters.UserReporting);
		Query.SetParameter("DisabledApplicationOptions", SearchParameters.DisabledApplicationOptions);
	Else
		Query.Text = StrReplace(
			Query.Text,
			"(ReportsVariants.Ref IN (&VariantsFoundBySearch)
			|				OR PredefinedLocation.Subsystem IN (&SubsystemsFoundBySearch))",
			"(ReportsVariants.Ref IN (&VariantsFoundBySearch))");
		Query.Text = StrReplace(
			Query.Text,
			"(LocationVariants.Ref IN (&VariantsFoundBySearch)
			|			OR LocationVariants.Subsystem IN (&SubsystemsFoundBySearch))",
			"LocationVariants.Ref IN (&VariantsFoundBySearch)");
		Query.Text = StrReplace(
			Query.Text,
			"
			|			AND (ReportsVariants.Report IN (&UserReporting))
			|			AND (NOT PredefinedLocation.Ref IN (&DisabledApplicationOptions))",
			"");
		Query.Text = StrReplace(
			Query.Text,
			"
			|	AND LocationVariants.Ref.Report IN(&UserReporting)
			|	AND NOT LocationVariants.Ref.PredefinedVariant IN (&DisabledApplicationOptions)",
			"");
	EndIf;
	
	If SettingMode Or UseBacklight Then
		RemovedFragment = 
			"WHERE ISNULL(PersonalSettings.Visible, AllVariants.VisibleByDefault)";
		Query.Text = StrReplace(Query.Text, RemovedFragment, "");
	EndIf;
	
	Query.TempTablesManager = New TempTablesManager;
	ResultTable = Query.Execute().Unload();
	ResultTable.Columns.Add("DisplayedTogetherWithMain", New TypeDescription("Boolean"));
	ResultTable.Columns.Add("SubordinateQuantity", New TypeDescription("Number"));
	//Ryabko Vitaly 2016-12-06 Task Задача №360:Локализация вариантов отчетов (	
	UserLanguge = InfoBaseUsers.CurrentUser().Language;
	If NOT UserLanguge = Undefined Then
		LangKey = InfoBaseUsers.CurrentUser().Language.LanguageCode;
		If Not LangKey = "en" Then
			For Each RepVar In ResultTable Do
				If RepVar.Ref.MultilingualValuesReports.Count() > 0 Then
					FindLoc = RepVar.Ref.MultilingualValuesReports.Find(LangKey,"LanguageKey");
					RepVar.Description = FindLoc.Description;
					RepVar.Definition = FindLoc.Definition;
				EndIf			
			EndDo;	
		EndIf;		
	EndIf; 
	//Ryabko Vitaly 2016-12-06 Task Задача №360:Локализация вариантов отчетов )
	If UseBacklight Then
		For Each KeyAndValue In SearchResult.VariantsConnectedToSubsystems Do
			VariantRef = KeyAndValue.Key;
			RelatedSubsystems = KeyAndValue.Value;
			Found = ResultTable.FindRows(New Structure("Ref", VariantRef));
			For Each TableRow In Found Do
				If RelatedSubsystems.Find(TableRow.Subsystem) = Undefined Then
					ResultTable.Delete(TableRow);
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	If OnlyCurrentSection Then
		OtherSections = New Array;
	Else
		TableCopy = ResultTable.Copy();
		TableCopy.GroupBy("SectionRef");
		OtherSections = TableCopy.UnloadColumn("SectionRef");
		IndexOf = OtherSections.Find(CurrentSectionRef);
		If IndexOf <> Undefined Then
			OtherSections.Delete(IndexOf);
		EndIf;
	EndIf;
	
	If UseBacklight Then
		ArrayOfWords = ReportsVariantsClientServer.DecomposeSearchStringIntoWordsArray(Upper(TrimAll(SearchString)));
	Else
		ArrayOfWords = Undefined;
	EndIf;
	
	FillingParameters.Insert("OnlyCurrentSection", OnlyCurrentSection);
	FillingParameters.Insert("SubsystemTable", SubsystemTable);
	FillingParameters.Insert("OtherSections", OtherSections);
	FillingParameters.Insert("Variants", ResultTable);
	FillingParameters.Insert("UseBacklight", ValueIsFilled(SearchString));
	FillingParameters.Insert("SearchResult", SearchResult);
	FillingParameters.Insert("ArrayOfWords", ArrayOfWords);
EndProcedure

&AtServer
Procedure OuputSectionVariants(FillingParameters, SectionRef)
	FilterBySection = New Structure("SectionRef", SectionRef);
	SectionVariants = FillingParameters.Variants.Copy(FilterBySection);
	FillingParameters.Insert("CurrentSectionVariantsDisplayed", SectionRef = CurrentSectionRef);
	FillingParameters.Insert("SectionVariants",    SectionVariants);
	FillingParameters.Insert("VariantsQuantity", SectionVariants.Count());
	If FillingParameters.VariantsQuantity = 0 Then
		// Displaying of the text explaining why there are no variants (only for current section).
		If FillingParameters.CurrentSectionVariantsDisplayed Then
			Label = Items.Insert("ReportListIsEmpty", Type("FormDecoration"), Items.WithoutGroupColumn1);
			If ValueIsFilled(SearchString) Then
				If FillingParameters.OnlyCurrentSection Then
					Label.Title = NStr("en='Reports are not found.';ru='Отчеты не найдены.'");
				Else
					Label.Title = NStr("en='Reports in the current section are not found.';ru='Отчеты в текущем разделе не найдены.'");
					Label.Height = 2;
				EndIf;
			Else
				Label.Title = NStr("en='No reports are located in reports panel of this section.';ru='В панели отчетов этого раздела не размещено ни одного отчета.'");
			EndIf;
			Items["QuickAccessHeader"].Visible  = False;
			Items["QuickAccessFooter"].Visible = False;
			Items["WithoutGroupFooter"].Visible  = False;
			Items["WithGroupFooter"].Visible   = False;
			Items["SeeAlsoFooter"].Visible    = False;
			Items.QuickAccessToolTipWhenNotConfigured.Visible = False;
		EndIf;
		Return;
	EndIf;
	
	If FillingParameters.OnlyCurrentSection Then
		SectionSubsystems = FillingParameters.SubsystemTable;
	Else
		SectionSubsystems = FillingParameters.SubsystemTable.Copy(FilterBySection);
	EndIf;
	SectionSubsystems.Sort("Priority ASC"); // Sorting by hierarchy
	
	FillingParameters.Insert("SectionRef",      SectionRef);
	FillingParameters.Insert("SectionSubsystems", SectionSubsystems);
	
	DefineGroupsAndDecorationsForVariantsOutput(FillingParameters);
	
	If Not FillingParameters.CurrentSectionVariantsDisplayed
		AND FillingParameters.LeftToOutput = 0 Then
		FillingParameters.DontOutput = FillingParameters.DontOutput + FillingParameters.VariantsQuantity;
		Return;
	EndIf;
	
	For Each GroupName In FillingParameters.ImportanceGroups Do
		GroupParameters = FillingParameters[GroupName];
		If FillingParameters.LeftToOutput <= 0 Then
			GroupParameters.Variants   = New Array;
			GroupParameters.Quantity = 0;
		Else
			GroupParameters.Variants   = FillingParameters.SectionVariants.Copy(GroupParameters.Filter);
			GroupParameters.Quantity = GroupParameters.Variants.Count();
		EndIf;
		
		If GroupParameters.Quantity = 0 AND Not (SettingMode AND GroupName = "WithGroup") Then
			Continue;
		EndIf;
		
		If Not FillingParameters.CurrentSectionVariantsDisplayed Then
			// Restriction on variants output.
			FillingParameters.LeftToOutput = FillingParameters.LeftToOutput - GroupParameters.Quantity;
			If FillingParameters.LeftToOutput < 0 Then
				// Deletion of rows that already exceed the limit.
				ExtraVariants = -FillingParameters.LeftToOutput;
				For Number = 1 To ExtraVariants Do
					GroupParameters.Variants.Delete(GroupParameters.Quantity - Number);
				EndDo;
				FillingParameters.DontOutput = FillingParameters.DontOutput + ExtraVariants;
				FillingParameters.LeftToOutput = 0;
			EndIf;
		EndIf;
		
		If SettingMode Then
			FillingParameters.ContextMenu.RemoveFromQuickAccess.Visible   = (GroupName = "QuickAccess");
			FillingParameters.ContextMenu.MoveToQuickAccess.Visible = (GroupName <> "QuickAccess");
		EndIf;
		
		FillingParameters.GroupName = GroupName;
		DisplayOptionsWithGroup(FillingParameters);
	EndDo;
	
	ThereIsQuickAccess     = (FillingParameters.QuickAccess.Quantity > 0);
	ThereAreVariantsWithoutGroup = (FillingParameters.WithoutGroup.Quantity > 0);
	ThereAreVariantsWithGroup  = (FillingParameters.WithGroup.Quantity > 0);
	ThereAreVariantsSeeAlso   = (FillingParameters.SeeAlso.Quantity > 0);
	
	Items[FillingParameters.Prefix + "QuickAccessHeader"].Visible  = SettingMode Or ThereIsQuickAccess;
	Items[FillingParameters.Prefix + "QuickAccessFooter"].Visible = (
		SettingMode
		Or (
			ThereIsQuickAccess
			AND (
				ThereAreVariantsWithoutGroup
				Or ThereAreVariantsWithGroup
				Or ThereAreVariantsSeeAlso
			)
		)
	);
	Items[FillingParameters.Prefix + "WithoutGroupFooter"].Visible  = ThereAreVariantsWithoutGroup;
	Items[FillingParameters.Prefix + "WithGroupFooter"].Visible   = ThereAreVariantsWithGroup;
	Items[FillingParameters.Prefix + "SeeAlsoFooter"].Visible    = ThereAreVariantsSeeAlso;
	
	If FillingParameters.CurrentSectionVariantsDisplayed Then
		Items.QuickAccessToolTipWhenNotConfigured.Visible = SettingMode AND Not ThereIsQuickAccess;
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineGroupsAndDecorationsForVariantsOutput(FillingParameters)
	// This procedure determines standard group and item substitutes.
	FillingParameters.Insert("Prefix", "");
	If FillingParameters.CurrentSectionVariantsDisplayed Then
		Return;
	EndIf;
	
	InformationAboutSection = FillingParameters.SubsystemTable.Find(FillingParameters.SectionRef, "Ref");
	FillingParameters.Prefix = "Section_" + InformationAboutSection.Priority + "_";
	
	SectionGroupName = FillingParameters.Prefix + InformationAboutSection.Name;
	SectionGroup = Items.Insert(SectionGroupName, Type("FormGroup"), Items.SearchResultsFromOtherSections);
	SectionGroup.Type         = FormGroupType.UsualGroup;
	SectionGroup.Representation = UsualGroupRepresentation.None;
	SectionGroup.ShowTitle      = False;
	SectionGroup.ToolTipRepresentation     = ToolTipRepresentation.ShowTop;
	SectionGroup.HorizontalStretch = True;
	
	SectionSuffix = " (" + Format(FillingParameters.VariantsQuantity, "NZ=0; NG=") + ")" + Chars.LF;
	If FillingParameters.UseBacklight Then
		HighlightParameters = FillingParameters.SearchResult.SubsystemsHighlight.Get(FillingParameters.SectionRef);
		If HighlightParameters = Undefined Then
			PresentationHighlight = New Structure("Value, FoundWordsCount, HighlightWords", InformationAboutSection.Presentation, 0, New ValueList);
			For Each Word In FillingParameters.ArrayOfWords Do
				ReportsVariants.MarkWord(PresentationHighlight, Word);
			EndDo;
		Else
			PresentationHighlight = HighlightParameters.SubsystemDescription;
		EndIf;
		PresentationHighlight.Value = PresentationHighlight.Value + SectionSuffix;
		If PresentationHighlight.FoundWordsCount > 0 Then
			SectionTitle = GenerateLineWithHighlight(PresentationHighlight);
		Else
			SectionTitle = PresentationHighlight.Value;
		EndIf;
	Else
		SectionTitle = InformationAboutSection.Presentation + SectionSuffix;
	EndIf;
	
	SectionTitle = SectionGroup.ExtendedTooltip;
	SectionTitle.Title   = SectionTitle;
	SectionTitle.Font       = SectionFont;
	SectionTitle.TextColor  = SectionColor;
	SectionTitle.Height      = 2;
	SectionTitle.Hyperlink = True;
	SectionTitle.VerticalAlign = ItemVerticalAlign.Top;
	SectionTitle.SetAction("Click", "SectionTitleClick");
	
	SectionGroup.Group = ChildFormItemsGroup.Horizontal;
	
	IndentDecorationName = FillingParameters.Prefix + "IndentDecoration";
	IndentDecoration = Items.Insert(IndentDecorationName, Type("FormDecoration"), SectionGroup);
	IndentDecoration.Type = FormDecorationType.Label;
	IndentDecoration.Title = " ";
	
	// Previously in other groups output limit is reached - there is no need to create subordinate ones.
	If FillingParameters.LeftToOutput = 0 Then
		SectionTitle.Height = 1; // There is no longer need to separate section title itself from variants.
		Return;
	EndIf;
	
	CopyItem(FillingParameters.Prefix, SectionGroup, "Columns", 2);
	
	Items.Delete(Items[FillingParameters.Prefix + "QuickAccessToolTipWhenNotConfigured"]);
	Items[FillingParameters.Prefix + "QuickAccessHeader"].ExtendedTooltip.Title = "";
EndProcedure

&AtServer
Function CopyItem(PrefixNew, GroupNew, CopiedName, NestingLevel)
	CopiedItem = Items.Find(CopiedName);
	NameOfNew = PrefixNew + CopiedName;
	NewItem = Items.Find(NameOfNew);
	PointType = TypeOf(CopiedItem);
	IsFolder = (PointType = Type("FormGroup"));
	If NewItem = Undefined Then
		NewItem = Items.Insert(NameOfNew, PointType, GroupNew);
	EndIf;
	If IsFolder Then
		NotFillableProperties = "Name, Parent, Visible, Shortcut, ChildItems, TitleDataPath";
	Else
		NotFillableProperties = "Name, Parent, Visible, Shortcut, ExtendedTooltip";
	EndIf;
	FillPropertyValues(NewItem, CopiedItem, , NotFillableProperties);
	If IsFolder AND NestingLevel > 0 Then
		For Each SubordinateItem In CopiedItem.ChildItems Do
			CopyItem(PrefixNew, NewItem, SubordinateItem.Name, NestingLevel - 1);
		EndDo;
	EndIf;
	Return NewItem;
EndFunction

&AtServer
Procedure DisplayOptionsWithGroup(FillingParameters)
	GroupParameters = FillingParameters[FillingParameters.GroupName];
	Variants = GroupParameters.Variants;
	VariantCount = GroupParameters.Quantity;
	If VariantCount = 0 AND Not (SettingMode AND FillingParameters.GroupName = "WithGroup") Then
		Return;
	EndIf;
	
	// Basic properties of 2 level group.
	GroupLevel2Name = FillingParameters.GroupName;
	Level2Group = Items.Find(FillingParameters.Prefix + GroupLevel2Name);
	
	OutputWithoutGroups = (GroupLevel2Name = "QuickAccess" Or GroupLevel2Name = "SeeAlso");
	
	// Sorting
	// of variants There are groups and i//mportant TopLevel DESC,
	Variants.Sort("SubsystemOfPriority ASC, Important DESC, Description ASC");
	FoundParents = Variants.FindRows(New Structure("TopLevel", True));
	For Each VarianParent In FoundParents Do
		FoundSubordinate = Variants.FindRows(New Structure("Parent, Subsystem", VarianParent.Ref, VarianParent.Subsystem));
		CurrentIndex = Variants.IndexOf(VarianParent);
		For Each VariantSubordinated In FoundSubordinate Do
			VarianParent.SubordinateQuantity = VarianParent.SubordinateQuantity + 1;
			VariantSubordinated.DisplayedTogetherWithMain = True;
			SubordinateIndex = Variants.IndexOf(VariantSubordinated);
			If SubordinateIndex < CurrentIndex Then
				Variants.Move(SubordinateIndex, CurrentIndex - SubordinateIndex);
			ElsIf SubordinateIndex = CurrentIndex Then
				CurrentIndex = CurrentIndex + 1;
			Else
				Variants.Move(SubordinateIndex, CurrentIndex - SubordinateIndex + 1);
				CurrentIndex = CurrentIndex + 1;
			EndIf;
		EndDo;
	EndDo;
	
	// Modeling of variants distribution considering subsystems nesting.
	DistributionTree = New ValueTree;
	DistributionTree.Columns.Add("Subsystem");
	DistributionTree.Columns.Add("SubsystemRef", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	DistributionTree.Columns.Add("Variants", New TypeDescription("Array"));
	DistributionTree.Columns.Add("VariantCount", New TypeDescription("Number"));
	DistributionTree.Columns.Add("NumberOfBlankRows", New TypeDescription("Number"));
	DistributionTree.Columns.Add("AllAttachedOptions", New TypeDescription("Number"));
	DistributionTree.Columns.Add("OnlyNestedSubsystems", New TypeDescription("Number"));
	DistributionTree.Columns.Add("TotalEnclosedBlankRows", New TypeDescription("Number"));
	DistributionTree.Columns.Add("NestingLevel", New TypeDescription("Number"));
	DistributionTree.Columns.Add("TopLevel", New TypeDescription("Boolean"));
	
	MaximumNestingLevel = 0;
	CurrentSubsystem = Undefined;
	
	For Each Subsystem In FillingParameters.SectionSubsystems Do
		
		ParentRow = DistributionTree.Rows.Find(Subsystem.ParentRef, "SubsystemRef", True);
		If ParentRow = Undefined Then
			TreeRow = DistributionTree.Rows.Add();
		Else
			TreeRow = ParentRow.Rows.Add();
		EndIf;
		
		TreeRow.Subsystem = Subsystem;
		TreeRow.SubsystemRef = Subsystem.Ref;
		
		If OutputWithoutGroups Then
			If Subsystem.Ref = FillingParameters.SectionRef Then
				For Each Variant In Variants Do
					TreeRow.Variants.Add(Variant);
				EndDo;
			EndIf;
		Else
			TreeRow.Variants = Variants.FindRows(New Structure("Subsystem", Subsystem.Ref));
		EndIf;
		TreeRow.VariantCount = TreeRow.Variants.Count();
		
		AreOptions = TreeRow.VariantCount > 0;
		If Not AreOptions Then
			TreeRow.NumberOfBlankRows = -1;
		EndIf;
		
		// Calculate the level of nesting, Quantity accounting in the hierarchy (if there are variants).
		If ParentRow <> Undefined Then
			While ParentRow <> Undefined Do
				If AreOptions Then
					ParentRow.AllAttachedOptions = ParentRow.AllAttachedOptions + TreeRow.VariantCount;
					ParentRow.OnlyNestedSubsystems = ParentRow.OnlyNestedSubsystems + 1;
					ParentRow.TotalEnclosedBlankRows = ParentRow.TotalEnclosedBlankRows + 1;
				EndIf;
				ParentRow = ParentRow.Parent;
				TreeRow.NestingLevel = TreeRow.NestingLevel + 1;
			EndDo;
		EndIf;
		
		MaximumNestingLevel = Max(MaximumNestingLevel, TreeRow.NestingLevel);
		
	EndDo;
	
	// Estimation of location column and need to transfer each subsystems basing on quantity data.
	FillingParameters.Insert("MaximumNestingLevel", MaximumNestingLevel);
	DistributionTree.Columns.Add("FormGroup");
	DistributionTree.Columns.Add("InitiatedWithdrawal", New TypeDescription("Boolean"));
	RootRow = DistributionTree.Rows[0];
	LineCount = RootRow.VariantCount + RootRow.AllAttachedOptions + RootRow.OnlyNestedSubsystems + Max(RootRow.TotalEnclosedBlankRows - 2, 0);
	
	// Variables for 3 level groups dynamics support.
	ColumnsCount = Level2Group.ChildItems.Count();
	If RootRow.VariantCount = 0 Then
		If ColumnsCount > 1 AND RootRow.AllAttachedOptions <= 5 Then
			ColumnsCount = 1;
		ElsIf ColumnsCount > 2 AND RootRow.AllAttachedOptions <= 10 Then
			ColumnsCount = 2;
		EndIf;
	EndIf;
	// Number of variants for output in one column.
	Group3LevelCutoff = Max(Int(LineCount / ColumnsCount), 2);
	
	OutputOrder = New ValueTable;
	OutputOrder.Columns.Add("ColumnNumber", New TypeDescription("Number"));
	OutputOrder.Columns.Add("ThisSubsystem", New TypeDescription("Boolean"));
	OutputOrder.Columns.Add("ThisIsContinuationOfThe", New TypeDescription("Boolean"));
	OutputOrder.Columns.Add("IsOption", New TypeDescription("Boolean"));
	OutputOrder.Columns.Add("ThisIsBlankString", New TypeDescription("Boolean"));
	OutputOrder.Columns.Add("TreeRow");
	OutputOrder.Columns.Add("Subsystem");
	OutputOrder.Columns.Add("SubsystemRef", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	OutputOrder.Columns.Add("SubsystemOfPriority", New TypeDescription("String"));
	OutputOrder.Columns.Add("Variant");
	OutputOrder.Columns.Add("VariantRef");
	OutputOrder.Columns.Add("NestingLevel", New TypeDescription("Number"));
	
	Recursion = New Structure;
	Recursion.Insert("LeftDisplay", LineCount);
	Recursion.Insert("FluentSpeakers", ColumnsCount - 1);
	Recursion.Insert("ColumnsCount", ColumnsCount);
	Recursion.Insert("Group3LevelCutoff", Group3LevelCutoff);
	Recursion.Insert("NumberOfCurrentColumn", 1);
	Recursion.Insert("ThisIsLastColumn", Recursion.NumberOfCurrentColumn = Recursion.ColumnsCount Or LineCount <= 6);
	Recursion.Insert("FreeLines", Group3LevelCutoff);
	Recursion.Insert("InitiatedOutputInCurrentColumn", False);
	
	FillOutputOrder(OutputOrder, Undefined, RootRow, Recursion, FillingParameters);
	
	// Output in form
	NumberOfCurrentColumn = 0;
	For Each OutputOrderString In OutputOrder Do
		
		If NumberOfCurrentColumn <> OutputOrderString.ColumnNumber Then
			NumberOfCurrentColumn = OutputOrderString.ColumnNumber;
			CurrentNestingLevel = 0;
			CurrentGroup = Level2Group.ChildItems.Get(NumberOfCurrentColumn - 1);
			CurrentGroupsByNestingLevels = New Map;
			CurrentGroupsByNestingLevels.Insert(0, CurrentGroup);
		EndIf;
		
		If OutputOrderString.ThisSubsystem Then
			
			If OutputOrderString.SubsystemRef = FillingParameters.SectionRef Then
				CurrentNestingLevel = 0;
				CurrentGroup = CurrentGroupsByNestingLevels.Get(0);
			Else
				CurrentNestingLevel = OutputOrderString.NestingLevel;
				IntoGroup = CurrentGroupsByNestingLevels.Get(OutputOrderString.NestingLevel - 1);
				CurrentGroup = AddSubsystemGroup(FillingParameters, OutputOrderString, IntoGroup);
				CurrentGroupsByNestingLevels.Insert(CurrentNestingLevel, CurrentGroup);
			EndIf;
			
		ElsIf OutputOrderString.IsOption Then
			
			If CurrentNestingLevel <> OutputOrderString.NestingLevel Then
				CurrentNestingLevel = OutputOrderString.NestingLevel;
				CurrentGroup = CurrentGroupsByNestingLevels.Get(CurrentNestingLevel);
			EndIf;
			
			AddReportVariantItems(FillingParameters, OutputOrderString.Variant, CurrentGroup, OutputOrderString.NestingLevel);
			
			If OutputOrderString.Variant.SubordinateQuantity > 0 Then
				CurrentNestingLevel = CurrentNestingLevel + 1;
				CurrentGroup = AddGroupWithIndented(FillingParameters, OutputOrderString, CurrentGroup);
				CurrentGroupsByNestingLevels.Insert(CurrentNestingLevel, CurrentGroup);
			EndIf;
			
		ElsIf OutputOrderString.ThisIsBlankString Then
			
			IntoGroup = CurrentGroupsByNestingLevels.Get(OutputOrderString.NestingLevel - 1);
			AddEmptyDecoration(FillingParameters, IntoGroup);
			
		EndIf;
		
	EndDo;
	
	For ColumnNumber = 3 To Level2Group.ChildItems.Count() Do
		Found = OutputOrder.FindRows(New Structure("ColumnNumber, ThisSubsystem", ColumnNumber, False));
		If Found.Count() = 0 Then
			Level3Group = Level2Group.ChildItems.Get(ColumnNumber - 1);
			AddEmptyDecoration(FillingParameters, Level3Group);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillOutputOrder(OutputOrder, ParentRow, TreeRow, Recursion, FillingParameters)
	
	If Not Recursion.ThisIsLastColumn AND Recursion.FreeLines <= 0 Then // current column
		// is exhausted Transition to a new column.
		Recursion.LeftDisplay = Recursion.LeftDisplay - 1; // Empty group that shall not be displayed.
		Recursion.NumberOfCurrentColumn = Recursion.NumberOfCurrentColumn + 1;
		Recursion.ThisIsLastColumn = (Recursion.NumberOfCurrentColumn = Recursion.ColumnsCount);
		FluentSpeakers = Recursion.ColumnsCount - Recursion.NumberOfCurrentColumn + 1;
		// Number of variants for output in one column.
		Recursion.Group3LevelCutoff = Max(Int(Recursion.LeftDisplay / FluentSpeakers), 2);
		Recursion.FreeLines = Recursion.Group3LevelCutoff; // Number of variants for output in one column.
		
		// Hierarchy output/ Repeat hierarchy with "(continued)" if output of the current parent lines has
		// already been initiated in the previous column.
		CurrentParent = ParentRow;
		While CurrentParent <> Undefined AND CurrentParent.SubsystemRef <> FillingParameters.SectionRef Do
			
			// Recursion.LeftDisplay does not decrease as continuation output increases quantity of rows.
			DisplaySubsystem = OutputOrder.Add();
			DisplaySubsystem.ColumnNumber        = Recursion.NumberOfCurrentColumn;
			DisplaySubsystem.ThisSubsystem       = True;
			DisplaySubsystem.ThisIsContinuationOfThe      = ParentRow.InitiatedWithdrawal;
			DisplaySubsystem.TreeRow        = TreeRow;
			DisplaySubsystem.SubsystemOfPriority = TreeRow.Subsystem.Priority;
			FillPropertyValues(DisplaySubsystem, CurrentParent, "Subsystem, SubsystemRef, NestingLevel");
			
			CurrentParent = CurrentParent.Parent;
		EndDo;
		
		Recursion.InitiatedOutputInCurrentColumn = False;
		
	EndIf;
	
	If (TreeRow.VariantCount > 0 Or TreeRow.AllAttachedOptions > 0) AND Recursion.InitiatedOutputInCurrentColumn AND ParentRow.InitiatedWithdrawal Then
		// Output of blank row.
		Recursion.LeftDisplay = Recursion.LeftDisplay - 1;
		OutputBlankRow = OutputOrder.Add();
		OutputBlankRow.ColumnNumber        = Recursion.NumberOfCurrentColumn;
		OutputBlankRow.ThisIsBlankString     = True;
		OutputBlankRow.TreeRow        = TreeRow;
		OutputBlankRow.SubsystemOfPriority = TreeRow.Subsystem.Priority;
		FillPropertyValues(OutputBlankRow, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
		
		// Accounting of rows occupied by an empty string.
		Recursion.FreeLines = Recursion.FreeLines - 1;
	EndIf;
	
	// Group output.
	If ParentRow <> Undefined Then
		DisplaySubsystem = OutputOrder.Add();
		DisplaySubsystem.ColumnNumber        = Recursion.NumberOfCurrentColumn;
		DisplaySubsystem.ThisSubsystem       = True;
		DisplaySubsystem.TreeRow        = TreeRow;
		DisplaySubsystem.SubsystemOfPriority = TreeRow.Subsystem.Priority;
		FillPropertyValues(DisplaySubsystem, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
	EndIf;
	
	If TreeRow.VariantCount > 0 Then
		
		// Accounting of row occupied by the group.
		Recursion.LeftDisplay = Recursion.LeftDisplay - 1;
		Recursion.FreeLines = Recursion.FreeLines - 1;
		
		TreeRow.InitiatedWithdrawal = True;
		Recursion.InitiatedOutputInCurrentColumn = True;
		
		If Recursion.ThisIsLastColumn
			Or ParentRow <> Undefined
			AND (TreeRow.VariantCount <= 5
			Or TreeRow.VariantCount - 2 <= Recursion.FreeLines + 2) Then
			
			// Output all in current column.
			ContinuationPossible = False;
			CountIntoCurrentColumn = TreeRow.VariantCount;
			
		Else
			
			// Partial output into the current column continued in the following.
			ContinuationPossible = True;
			CountIntoCurrentColumn = Max(Recursion.FreeLines + 2, 3);
			
		EndIf;
		
		// Registration of variants in current column /Additional output of variants in new column.
		VariantsDisplayed = 0;
		For Each Variant In TreeRow.Variants Do
			// TreeRow.Variants - this is search result in the table of values.
			// Code is designed so that sorting of search result does not differ from the lines sorting.
			// If this is not the case, then
			// the original table shall be copied with filter by subsystem and sort by description.
			
			If ContinuationPossible
				AND Not Recursion.ThisIsLastColumn
				AND Not Variant.DisplayedTogetherWithMain
				AND VariantsDisplayed >= CountIntoCurrentColumn Then
				// Transition to a new column.
				Recursion.NumberOfCurrentColumn = Recursion.NumberOfCurrentColumn + 1;
				Recursion.ThisIsLastColumn = (Recursion.NumberOfCurrentColumn = Recursion.ColumnsCount);
				FluentSpeakers = Recursion.ColumnsCount - Recursion.NumberOfCurrentColumn + 1;
				// Number of variants for output in one column.
				Recursion.Group3LevelCutoff = Max(Int(Recursion.LeftDisplay / FluentSpeakers), 2);
				Recursion.FreeLines = Recursion.Group3LevelCutoff; // Number of variants for output in one column.
				
				If Recursion.ThisIsLastColumn Then
					CountIntoCurrentColumn = -1;
				Else
					CountIntoCurrentColumn = Max(min(Recursion.FreeLines, TreeRow.VariantCount - VariantsDisplayed), 3);
				EndIf;
				VariantsDisplayed = 0;
				
				// Repeat of hierarchy laced with "(continued)".
				CurrentParent = ParentRow;
				While CurrentParent <> Undefined AND CurrentParent.SubsystemRef <> FillingParameters.SectionRef Do
					
					// Recursion.LeftDisplay does not decrease as continuation output increases quantity of rows.
					DisplaySubsystem = OutputOrder.Add();
					DisplaySubsystem.ColumnNumber        = Recursion.NumberOfCurrentColumn;
					DisplaySubsystem.ThisSubsystem       = True;
					DisplaySubsystem.ThisIsContinuationOfThe      = True;
					DisplaySubsystem.TreeRow        = TreeRow;
					DisplaySubsystem.SubsystemOfPriority = TreeRow.Subsystem.Priority;
					FillPropertyValues(DisplaySubsystem, CurrentParent, "Subsystem, SubsystemRef, NestingLevel");
					
					CurrentParent = CurrentParent.Parent;
				EndDo;
				
				// Output of a group laced with "(continued)".
				// Recursion.LeftDisplay does not decrease as continuation output increases quantity of rows.
				DisplaySubsystem = OutputOrder.Add();
				DisplaySubsystem.ColumnNumber        = Recursion.NumberOfCurrentColumn;
				DisplaySubsystem.ThisSubsystem       = True;
				DisplaySubsystem.ThisIsContinuationOfThe      = True;
				DisplaySubsystem.TreeRow        = TreeRow;
				DisplaySubsystem.SubsystemOfPriority = TreeRow.Subsystem.Priority;
				FillPropertyValues(DisplaySubsystem, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
				
				// Accounting of row occupied by the group.
				Recursion.FreeLines = Recursion.FreeLines - 1;
			EndIf;
			
			Recursion.LeftDisplay = Recursion.LeftDisplay - 1;
			DisplayVariant = OutputOrder.Add();
			DisplayVariant.ColumnNumber        = Recursion.NumberOfCurrentColumn;
			DisplayVariant.IsOption          = True;
			DisplayVariant.TreeRow        = TreeRow;
			DisplayVariant.Variant             = Variant;
			DisplayVariant.VariantRef       = Variant.Ref;
			DisplayVariant.SubsystemOfPriority = TreeRow.Subsystem.Priority;
			FillPropertyValues(DisplayVariant, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
			If Variant.DisplayedTogetherWithMain Then
				DisplayVariant.NestingLevel = DisplayVariant.NestingLevel + 1;
			EndIf;
			
			VariantsDisplayed = VariantsDisplayed + 1;
			
			// Accounting of lines occupied by variants.
			Recursion.FreeLines = Recursion.FreeLines - 1;
		EndDo;
		
	EndIf;
	
	// Registration of nested lines.
	For Each StringSubordinate In TreeRow.Rows Do
		FillOutputOrder(OutputOrder, TreeRow, StringSubordinate, Recursion, FillingParameters);
		// Forwarding InitiatedOutput from the lower level.
		If StringSubordinate.InitiatedWithdrawal Then
			TreeRow.InitiatedWithdrawal = True;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function AddSubsystemGroup(FillingParameters, OutputOrderString, IntoGroup)
	Subsystem = OutputOrderString.Subsystem;
	TreeRow = OutputOrderString.TreeRow;
	If TreeRow.VariantCount = 0
		AND TreeRow.AllAttachedOptions = 0
		AND Not (SettingMode AND FillingParameters.GroupName = "WithGroup") Then
		Return IntoGroup;
	EndIf;
	SubsystemPresentation = Subsystem.Presentation;
	
	Subsystem.ItemNumber = Subsystem.ItemNumber + 1;
	SubsystemGroupName = Subsystem.ItemName + "_" + Format(Subsystem.ItemNumber, "NG=0");
	
	// Insert the left indent.
	If OutputOrderString.NestingLevel > 1 Then
		// Group.
		IndentGroup = Items.Insert(SubsystemGroupName + "_IndentGroup", Type("FormGroup"), IntoGroup);
		IndentGroup.Type                      = FormGroupType.UsualGroup;
		IndentGroup.Group              = ChildFormItemsGroup.Horizontal;
		IndentGroup.Representation              = UsualGroupRepresentation.None;
		IndentGroup.ShowTitle      = False;
		IndentGroup.HorizontalStretch = True;
		
		// Picture.
		PictureInset = Items.Insert(SubsystemGroupName + "_PictureInset", Type("FormDecoration"), IndentGroup);
		FillPropertyValues(PictureInset, FillingParameters.Patterns.PictureInset);
		PictureInset.Width = OutputOrderString.NestingLevel - 1;
		If OutputOrderString.TreeRow.VariantCount = 0 AND OutputOrderString.TreeRow.AllAttachedOptions = 0 Then
			PictureInset.Visible = False;
		EndIf;
		
		// Substitution of upper level group.
		IntoGroup = IndentGroup;
		
		TitleFont = CommonGroupFont;
	Else
		TitleFont = ImportantGroupFont;
	EndIf;
	
	GroupSubsystems = Items.Insert(SubsystemGroupName, Type("FormGroup"), IntoGroup);
	GroupSubsystems.Type = FormGroupType.UsualGroup;
	GroupSubsystems.HorizontalStretch = True;
	GroupSubsystems.Group = ChildFormItemsGroup.Vertical;
	GroupSubsystems.Representation = UsualGroupRepresentation.None;
	
	IlluminationRequired = False;
	If FillingParameters.UseBacklight Then
		HighlightParameters = FillingParameters.SearchResult.SubsystemsHighlight.Get(Subsystem.Ref);
		If HighlightParameters <> Undefined Then
			PresentationHighlight = HighlightParameters.SubsystemDescription;
			If PresentationHighlight.FoundWordsCount > 0 Then
				IlluminationRequired = True;
			EndIf;
		EndIf;
	EndIf;
	
	If IlluminationRequired Then
		If OutputOrderString.ThisIsContinuationOfThe Then
			Suffix = NStr("en='(continued)';ru='(продолжение)'");
			If Right(PresentationHighlight.Value, StrLen(Suffix)) <> Suffix Then
				PresentationHighlight.Value = PresentationHighlight.Value + " " + Suffix;
			EndIf;
		EndIf;
		
		GroupSubsystems.ShowTitle = False;
		GroupSubsystems.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
		
		FormattedString = GenerateLineWithHighlight(PresentationHighlight);
		
		SubsystemTitle = Items.Insert(GroupSubsystems.Name + "_ExtendedTooltip", Type("FormDecoration"), GroupSubsystems);
		SubsystemTitle.Title  = FormattedString;
		SubsystemTitle.TextColor = ReportVariantsGroupsColour;
		SubsystemTitle.Font      = TitleFont;
		SubsystemTitle.HorizontalStretch = True;
		SubsystemTitle.Height = 1;
		
	Else
		If OutputOrderString.ThisIsContinuationOfThe Then
			SubsystemPresentation = SubsystemPresentation + " " + NStr("en='(continued)';ru='(продолжение)'");
		EndIf;
		
		GroupSubsystems.ShowTitle = True;
		GroupSubsystems.Title           = SubsystemPresentation;
		GroupSubsystems.TitleTextColor = ReportVariantsGroupsColour;
		GroupSubsystems.TitleFont      = TitleFont;
	EndIf;
	
	TreeRow.FormGroup = GroupSubsystems;
	
	Return GroupSubsystems;
EndFunction

&AtServer
Function AddGroupWithIndented(FillingParameters, OutputOrderString, IntoGroup)
	ItemsOptionsDisplayed = ItemsOptionsDisplayed + 1;
	
	IndentGroupName   = "IndentGroup_" + Format(ItemsOptionsDisplayed, "NG=0");
	IndentPictureName = "PictureInset_" + Format(ItemsOptionsDisplayed, "NG=0");
	OutputGroupName    = "OutputGroup_" + Format(ItemsOptionsDisplayed, "NG=0");
	
	// Indent.
	IndentGroup = Items.Insert(IndentGroupName, Type("FormGroup"), IntoGroup);
	IndentGroup.Type                      = FormGroupType.UsualGroup;
	IndentGroup.Group              = ChildFormItemsGroup.Horizontal;
	IndentGroup.Representation              = UsualGroupRepresentation.None;
	IndentGroup.ShowTitle      = False;
	IndentGroup.HorizontalStretch = True;
	
	// Picture.
	PictureInset = Items.Insert(IndentPictureName, Type("FormDecoration"), IndentGroup);
	FillPropertyValues(PictureInset, FillingParameters.Patterns.PictureInset);
	PictureInset.Width = 1;
	
	// Output.
	OutputGroup = Items.Insert(OutputGroupName, Type("FormGroup"), IndentGroup);
	OutputGroup.Type                      = FormGroupType.UsualGroup;
	OutputGroup.Group              = ChildFormItemsGroup.Vertical;
	OutputGroup.Representation              = UsualGroupRepresentation.None;
	OutputGroup.ShowTitle      = False;
	OutputGroup.HorizontalStretch = True;
	
	Return OutputGroup;
EndFunction

&AtServer
Function AddReportVariantItems(FillingParameters, Variant, IntoGroup, NestingLevel = 0)
	
	// Distinct name of the added item.
	ItemsOptionsDisplayed = ItemsOptionsDisplayed + 1;
	TitleName = "AddedItem_" + Format(ItemsOptionsDisplayed, "NG=0");
	
	If SettingMode Then
		VariantGroupName = "Group_" + TitleName;
		VariantGroup = Items.Insert(VariantGroupName, Type("FormGroup"), IntoGroup);
		FillPropertyValues(VariantGroup, FillingParameters.Patterns.VariantGroup);
	Else
		VariantGroup = IntoGroup;
	EndIf;
	
	// Insert a check box (is not used for quick access).
	If SettingMode Then
		FlagName = "CheckBox_" + TitleName;
		
		FormAttribute = New FormAttribute(FlagName, New TypeDescription("Boolean"), , , False);
		FillingParameters.AttributesToAdd.Add(FormAttribute);
		
		CheckBox = Items.Insert(FlagName, Type("FormField"), VariantGroup);
		CheckBox.Type = FormFieldType.CheckBoxField;
		CheckBox.TitleLocation = FormItemTitleLocation.None;
		CheckBox.Visible = (FillingParameters.GroupName <> "QuickAccess");
		CheckBox.SetAction("OnChange", "VisibleOptionsOnChange");
	EndIf;
	
	// Adding label-hyperlink of the report variant.
	Label = Items.Insert(TitleName, Type("FormDecoration"), VariantGroup);
	FillPropertyValues(Label, FillingParameters.Patterns.InscriptionOptions);
	Label.Title = TrimAll(Variant.Description);
	If ValueIsFilled(Variant.Definition) Then
		Label.ToolTip = TrimAll(Variant.Definition);
	EndIf;
	If ValueIsFilled(Variant.Author) Then
		Label.ToolTip = TrimL(Label.ToolTip + Chars.LF) + NStr("en='Author:';ru='Автор:'") + " " + TrimAll(String(Variant.Author));
	EndIf;
	Label.SetAction("Click", "VariantPress");
	If Not Variant.Visible Then
		Label.TextColor = HiddenVariantsColour;
	EndIf;
	If Variant.Important
		AND FillingParameters.GroupName <> "SeeAlso"
		AND FillingParameters.GroupName <> "QuickAccess" Then
		Label.Font = ImportantInscriptionFont;
	EndIf;
	
	ToolTipContent = New Array;
	DefineVariantToolTipContent(FillingParameters, Variant, ToolTipContent, Label);
	OutputVariantToolTip(Label, ToolTipContent);
	
	If SettingMode Then
		For Each KeyAndValue In FillingParameters.ContextMenu Do
			Command_Name = KeyAndValue.Key;
			ButtonName = Command_Name + "_" + TitleName;
			Button = Items.Insert(ButtonName, Type("FormButton"), Label.ContextMenu);
			If WebClient Then
				Command = Commands.Add(ButtonName);
				FillPropertyValues(Command, Commands[Command_Name]);
				Button.CommandName = ButtonName;
			Else
				Button.CommandName = Command_Name;
			EndIf;
			FillPropertyValues(Button, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	// Registration of added inscription.
	TableRow = AddedVariants.Add();
	FillPropertyValues(TableRow, Variant);
	TableRow.GroupLevel2Name     = FillingParameters.GroupName;
	TableRow.TitleName           = TitleName;
	
	Return Label;
	
EndFunction

&AtServer
Procedure DefineVariantToolTipContent(FillingParameters, Variant, ToolTipContent, Label)
	ToolTipDisplayed = False;
	If FillingParameters.UseBacklight Then
		HighlightParameters = FillingParameters.SearchResult.HighlightOptions.Get(Variant.Ref);
		If HighlightParameters <> Undefined Then
			If HighlightParameters.VariantName.FoundWordsCount > 0 Then
				Label.Title = GenerateLineWithHighlight(HighlightParameters.VariantName);
			EndIf;
			If HighlightParameters.Definition.FoundWordsCount > 0 Then
				GenerateLineWithHighlight(HighlightParameters.Definition, ToolTipContent);
				ToolTipDisplayed = True;
			EndIf;
			If HighlightParameters.AuthorPresentation.FoundWordsCount > 0 Then
				If ToolTipContent.Count() > 0 Then
					ToolTipContent.Add(Chars.LF);
				EndIf;
				ToolTipContent.Add(NStr("en='Author:';ru='Автор:'") + " ");
				GenerateLineWithHighlight(HighlightParameters.AuthorPresentation, ToolTipContent);
				ToolTipContent.Add(".");
				ToolTipDisplayed = True;
			EndIf;
			If HighlightParameters.UserSettingsNames.FoundWordsCount > 0 Then
				If ToolTipContent.Count() > 0 Then
					ToolTipContent.Add(Chars.LF);
				EndIf;
				ToolTipContent.Add(NStr("en='Saved settings:';ru='Сохраненные настройки:'") + " ");
				GenerateLineWithHighlight(HighlightParameters.UserSettingsNames, ToolTipContent);
				ToolTipContent.Add(".");
			EndIf;
			If HighlightParameters.FieldNames.FoundWordsCount > 0 Then
				If ToolTipContent.Count() > 0 Then
					ToolTipContent.Add(Chars.LF);
				EndIf;
				ToolTipContent.Add(NStr("en='Fields:';ru='Поля:'") + " ");
				GenerateLineWithHighlight(HighlightParameters.FieldNames, ToolTipContent);
				ToolTipContent.Add(".");
			EndIf;
			If HighlightParameters.ParametersAndFiltersNames.FoundWordsCount > 0 Then
				If ToolTipContent.Count() > 0 Then
					ToolTipContent.Add(Chars.LF);
				EndIf;
				ToolTipContent.Add(NStr("en='Settings:';ru='Настройка:'") + " ");
				GenerateLineWithHighlight(HighlightParameters.ParametersAndFiltersNames, ToolTipContent);
				ToolTipContent.Add(".");
			EndIf;
		EndIf;
	EndIf;
	If Not ToolTipDisplayed AND ShowToolTips Then
		ToolTipContent.Add(TrimAll(Label.ToolTip));
	EndIf;
EndProcedure

&AtServer
Procedure OutputVariantToolTip(Label, ToolTipContent)
	If ToolTipContent.Count() = 0 Then
		Return;
	EndIf;
	
	FormattedString = New FormattedString(ToolTipContent);
	
	Label.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	Label.ExtendedTooltip.Title = FormattedString;
	Label.ExtendedTooltip.HorizontalStretch = True;
	Label.ExtendedTooltip.TextColor = ColorTips;
EndProcedure

&AtServer
Function GenerateLineWithHighlight(SearchArea, Content = Undefined)
	ReturnFormattedRow = False;
	If Content = Undefined Then
		ReturnFormattedRow = True;
		Content = New Array;
	EndIf;
	
	SourceText = SearchArea.Value;
	
	SearchArea.HighlightWords.SortByValue(SortDirection.Asc);
	QuantityOpen = 0;
	BeginningPositionForPlainText = 1;
	HighlightBeginningPosition = 0;
	For Each ItemOfList In SearchArea.HighlightWords Do
		Highlight = (ItemOfList.Presentation = "+");
		QuantityOpen = QuantityOpen + ?(Highlight, 1, -1);
		If Highlight AND QuantityOpen = 1 Then
			HighlightBeginningPosition = ItemOfList.Value;
			PlainTextFragment = Mid(SourceText, BeginningPositionForPlainText, HighlightBeginningPosition - BeginningPositionForPlainText);
			Content.Add(PlainTextFragment);
		ElsIf Not Highlight AND QuantityOpen = 0 Then
			BeginningPositionForPlainText = ItemOfList.Value;
			HighlightedFragment = Mid(SourceText, HighlightBeginningPosition, BeginningPositionForPlainText - HighlightBeginningPosition);
			Content.Add(New FormattedString(HighlightedFragment, , , ColorIlluminationFoundWords));
		EndIf;
	EndDo;
	If BeginningPositionForPlainText <= StrLen(SourceText) Then
		PlainTextFragment = Mid(SourceText, BeginningPositionForPlainText);
		Content.Add(PlainTextFragment);
	EndIf;
	
	If ReturnFormattedRow Then
		Return New FormattedString(Content);
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServer
Function AddEmptyDecoration(FillingParameters, IntoGroup)
	
	FillingParameters.AddedEmptyDecorations = FillingParameters.AddedEmptyDecorations + 1;
	DecorationName = "EmptyDecoration_" + Format(FillingParameters.AddedEmptyDecorations, "NG=0");
	
	Decoration = Items.Insert(DecorationName, Type("FormDecoration"), IntoGroup);
	Decoration.Type = FormDecorationType.Label;
	Decoration.Title = " ";
	Decoration.HorizontalStretch = True;
	
	Return Decoration;
	
EndFunction

#EndRegion













