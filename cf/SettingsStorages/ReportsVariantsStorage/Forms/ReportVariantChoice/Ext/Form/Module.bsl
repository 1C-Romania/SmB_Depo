#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	VariantKey = Parameters.CurrentSettingsKey;
	CurrentUser = Users.CurrentUser();
	
	ReportInformation = ReportsVariants.GenerateInformationAboutReportByDescriptionFull(Parameters.ObjectKey);
	If TypeOf(ReportInformation.ErrorText) = Type("String") Then
		Raise ReportInformation.ErrorText;
	EndIf;
	ReportInformation.Delete("ReportMetadata");
	ReportInformation.Delete("ErrorText");
	ReportInformation.Insert("ReportFullName", Parameters.ObjectKey);
	ReportInformation = New FixedStructure(ReportInformation);
	
	FullRightsForVariants = ReportsVariants.FullRightsForVariants();
	
	If Not FullRightsForVariants Then
		Items.ShowPersonalOptionsForReportsByOtherAuthors.Visible = False;
		Items.ShowPersonalOptionsForReportsByOtherAuthorsKM.Visible = False;
		ShowPersonalOptionsForReportsByOtherAuthors = False;
	EndIf;
	
	FillVariantsList();
	
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	Show = Settings.Get("ShowPersonalOptionsForReportsByOtherAuthors");
	If Show <> ShowPersonalOptionsForReportsByOtherAuthors Then
		ShowPersonalOptionsForReportsByOtherAuthors = Show;
		Items.ShowPersonalOptionsForReportsByOtherAuthors.Check = Show;
		Items.ShowPersonalOptionsForReportsByOtherAuthorsKM.Check = Show;
		FillVariantsList();
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = ReportsVariantsClientServer.EventNameOptionChanging() Then
		FillVariantsList();
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FilterAuthorOnModification(Item)
	FilterIsOn = ValueIsFilled(SelectAuthor);
	
	Groups = ReportVariantsTree.GetItems();
	For Each GroupVar IN Groups Do
		EnclosedVariants = GroupVar.GetItems();
		For Each Variant IN EnclosedVariants Do
			Variant.HiddenBySelection = FilterIsOn AND Variant.Author <> SelectAuthor;
		EndDo;
	EndDo;
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersReportVariantTree

&AtClient
Procedure ReportVariantsTreeOnActivateRow(Item)
	Variant = Items.ReportVariantsTree.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Variant.VariantKey) Then
		VariantDescription = "";
	Else
		VariantDescription = Variant.Definition;
	EndIf;
EndProcedure

&AtClient
Procedure ReportVariantsTreeBeforeModification(Item, Cancel)
	Cancel = True;
	OpenVariantForModification();
EndProcedure

&AtClient
Procedure ReportVariantsTreeBeforeInserting(Item, Cancel, Copy, Parent, Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ReportVariantsTreeBeforeDeletion(Item, Cancel)
	Cancel = True;
	
	Variant = Items.ReportVariantsTree.CurrentData;
	If Variant = Undefined OR Not ValueIsFilled(Variant.VariantKey) Then
		Return;
	EndIf;
	
	If Variant.PictureIndex = 4 Then
		QuestionText = NStr("en='Unmark ""%1"" for deletion?';ru='Снять с ""%1"" пометку на удаление?'");
	Else
		QuestionText = NStr("en='Mark ""%1"" for deletion?';ru='Пометить ""%1"" на удаление?'");
	EndIf;
	QuestionText = StrReplace(QuestionText, "%1", Variant.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Variant", Variant);
	Handler = New NotifyDescription("ReportVariantTreeBeforeDeletionEnd", ThisObject, AdditionalParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure ReportVariantsTreeSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ChooseAndClose();
EndProcedure

&AtClient
Procedure ReportVariantsTreeValueChoice(Item, Value, StandardProcessing)
	StandardProcessing = False;
	ChooseAndClose();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ShowPersonalOptionsForReportsByOtherAuthors(Command)
	ShowPersonalOptionsForReportsByOtherAuthors = Not ShowPersonalOptionsForReportsByOtherAuthors;
	Items.ShowPersonalOptionsForReportsByOtherAuthors.Check = ShowPersonalOptionsForReportsByOtherAuthors;
	Items.ShowPersonalOptionsForReportsByOtherAuthorsKM.Check = ShowPersonalOptionsForReportsByOtherAuthors;
	
	FillVariantsList();
	
	For Each TreeGroup IN ReportVariantsTree.GetItems() Do
		If TreeGroup.HiddenBySelection = False Then
			Items.ReportVariantsTree.Expand(TreeGroup.GetID(), True);
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure Refresh(Command)
	FillVariantsList();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Fields = "ReportVariantTree, ReportVariantTreePresentation, ReportVariantTreeAuthor";
	Instruction.Filters.Insert("ReportVariantTree.HiddenByFilter", True);
	Instruction.Appearance.Insert("Visible", False);
	Instruction.Appearance.Insert("Show", False);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = ReportsVariants.ConditionalDesignInstruction();
	Instruction.Fields = "ReportVariantTreePresentation, ReportVariantTreeAuthor";
	Instruction.Filters.Insert("ReportVariantTree.AuthorCurrentUser", True);
	Instruction.Appearance.Insert("TextColor", StyleColors.MyReportsVariantsColor);
	ReportsVariants.AddConditionalAppearanceItem(ThisObject, Instruction);
EndProcedure

&AtClient
Procedure ChooseAndClose()
	Variant = Items.ReportVariantsTree.CurrentData;
	If Variant = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Variant.VariantKey) Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("VariantKey", Variant.VariantKey);
	If Variant.PictureIndex = 4 Then
		QuestionText = NStr("en='Selected report variant is marked for deletion.
		|Select this report variant?';ru='Выбранный вариант отчета помечен на удаление.
		|Выбрать этот варианта отчета?'");
		Handler = New NotifyDescription("SelectAndCloseEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60);
	Else
		SelectAndCloseEnd(DialogReturnCode.Yes, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectAndCloseEnd(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Close(New SettingsChoice(AdditionalParameters.VariantKey));
	EndIf;
EndProcedure

&AtClient
Procedure OpenVariantForModification()
	Variant = Items.ReportVariantsTree.CurrentData;
	If Variant = Undefined OR Not ValueIsFilled(Variant.Ref) Then
		Return;
	EndIf;
	If Not VariantModificationRight(Variant, FullRightsForVariants) Then
		WarningText = NStr("en='The access rights are not sufficient to change the variant ""%1"".';ru='Недостаточно прав доступа для изменения варианта ""%1"".'");
		WarningText = StrReplace(WarningText, "%1", Variant.Description);
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	ShowValue(, Variant.Ref);
EndProcedure

&AtClient
Procedure ReportVariantTreeBeforeDeletionEnd(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		DeleteVariantOnServer(AdditionalParameters.Variant.Ref, AdditionalParameters.Variant.PictureIndex);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function VariantModificationRight(Variant, FullRightsForVariants)
	Return FullRightsForVariants OR Variant.AuthorCurrentUser;
EndFunction

&AtServer
Procedure FillVariantsList()
	
	CurrentVariantKey = VariantKey;
	If ValueIsFilled(Items.ReportVariantsTree.CurrentRow) Then
		CurrentTreeRow = ReportVariantsTree.FindByID(Items.ReportVariantsTree.CurrentRow);
		If ValueIsFilled(CurrentTreeRow.VariantKey) Then
			CurrentVariantKey = CurrentTreeRow.VariantKey;
		EndIf;
	EndIf;
	
	QueryText =
	"SELECT ALLOWED
	|	ReportsVariants.Ref,
	|	ReportsVariants.Description,
	|	ReportsVariants.VariantKey,
	|	CAST(ReportsVariants.Definition AS String(200)) AS Definition,
	|	ISNULL(ReportsVariants.PredefinedVariant.VisibleByDefault, FALSE) AS VisibleByDefault,
	|	ReportsVariants.Author,
	|	ReportsVariants.ForAuthorOnly,
	|	ReportsVariants.User,
	|	ReportsVariants.DeletionMark,
	|	ReportsVariants.PredefinedVariant
	|INTO ttOptions
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND (ReportsVariants.User = TRUE
	|			OR ReportsVariants.DeletionMark = FALSE)
	|	AND (ReportsVariants.ForAuthorOnly = FALSE
	|			OR ReportsVariants.Author = &CurrentUser)
	|	AND Not ReportsVariants.PredefinedVariant IN (&DisabledApplicationOptions)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsVariants.Ref AS Ref,
	|	LocationVariants.Use AS Use,
	|	LocationVariants.Subsystem AS Subsystem
	|INTO ttAdministratorPlacement
	|FROM
	|	ttOptions AS ReportsVariants
	|		INNER JOIN Catalog.ReportsVariants.Placement AS LocationVariants
	|		ON ReportsVariants.Ref = LocationVariants.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsVariants.Ref AS Ref,
	|	PredefinedLocation.Subsystem AS Subsystem
	|INTO ttDeveloperPlacement
	|FROM
	|	ttOptions AS ReportsVariants
	|		INNER JOIN Catalog.PredefinedReportsVariants.Placement AS PredefinedLocation
	|		ON (ReportsVariants.User = FALSE)
	|			AND ReportsVariants.PredefinedVariant = PredefinedLocation.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ISNULL(AdministratorPlacement.Ref, DeveloperPlacement.Ref) AS Ref,
	|	ISNULL(AdministratorPlacement.Subsystem, DeveloperPlacement.Subsystem) AS Subsystem,
	|	ISNULL(AdministratorPlacement.Use, TRUE) AS Use,
	|	CASE
	|		WHEN AdministratorPlacement.Ref IS NULL 
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DeveloperSetting
	|INTO ttVariantPlacement
	|FROM
	|	ttAdministratorPlacement AS AdministratorPlacement
	|		Full JOIN ttDeveloperPlacement AS DeveloperPlacement
	|		ON AdministratorPlacement.Ref = DeveloperPlacement.Ref
	|			AND AdministratorPlacement.Subsystem = DeveloperPlacement.Subsystem
	|WHERE
	|	ISNULL(AdministratorPlacement.Use, TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Placement.Ref AS Ref,
	|	MAX(ISNULL(PersonalSettings.Visible, Variants.VisibleByDefault)) AS VisibleInReportsPanel
	|INTO ttVisible
	|FROM
	|	ttVariantPlacement AS Placement
	|		LEFT JOIN InformationRegister.ReportsVariantsSettings AS PersonalSettings
	|		ON Placement.Subsystem = PersonalSettings.Subsystem
	|			AND Placement.Ref = PersonalSettings.Variant
	|			AND (PersonalSettings.User = &CurrentUser)
	|		LEFT JOIN ttOptions AS Variants
	|		ON Placement.Ref = Variants.Ref
	|
	|GROUP BY
	|	Placement.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Variants.Ref,
	|	Variants.Description,
	|	Variants.VariantKey,
	|	Variants.VisibleByDefault,
	|	Variants.Author,
	|	Variants.ForAuthorOnly,
	|	Variants.User,
	|	Variants.DeletionMark,
	|	CASE
	|		WHEN Variants.DeletionMark = TRUE
	|			THEN 3
	|		WHEN Visible.VisibleInReportsPanel = TRUE
	|			THEN 1
	|		ELSE 2
	|	END AS GroupNumber,
	|	Variants.Definition,
	|	CASE
	|		WHEN Variants.DeletionMark
	|			THEN 4
	|		WHEN Variants.User
	|			THEN 3
	|		ELSE 5
	|	END AS PictureIndex,
	|	CASE
	|		WHEN Variants.Author = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AuthorCurrentUser
	|FROM
	|	ttOptions AS Variants
	|		LEFT JOIN ttVisible AS Visible
	|		ON Variants.Ref = Visible.Ref";
	
	
	Query = New Query;
	Query.SetParameter("Report", ReportInformation.Report);
	Query.SetParameter("CurrentUser", CurrentUser);
	Query.SetParameter("DisabledApplicationOptions", ReportsVariantsReUse.DisabledApplicationOptions());
	
	If ShowPersonalOptionsForReportsByOtherAuthors Then
		QueryText = StrReplace(QueryText, "And (ReportsVariants.OnlyForAuthor
		|			= FALSE OR ReportsVariants.Author = &CurrentUser)", "");
	EndIf;
	
	Query.Text = QueryText;
	
	VariantTable = Query.Execute().Unload();
	
	// Add predefined variants of external report to the variants table (for sorting when adding to a tree).
	If ReportInformation.ReportType = Enums.ReportsTypes.External Then
		
		Try
			ReportObject = ExternalReports.Create(ReportInformation.ReportName);
		Except
			ReportsVariants.ErrorByVariant(Undefined,
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Failed to receive a predefined
		|variants list of the external report ""%1"":';ru='Не удалось получить
		|список предопределенных вариантов внешнего отчета ""%1"":'"),
					ReportInformation.ReportName
				) + Chars.LF + DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		If ReportObject.DataCompositionSchema <> Undefined Then
			For Each DCSettingsVariant IN ReportObject.DataCompositionSchema.SettingVariants Do
				Variant = VariantTable.Add();
				Variant.GroupNumber    = 1;
				Variant.VariantKey   = DCSettingsVariant.Name;
				Variant.Description   = DCSettingsVariant.Presentation;
				Variant.PictureIndex = 5;
				Variant.AuthorCurrentUser = False;
			EndDo;
		EndIf;
		
	EndIf;
	
	VariantTable.Sort("GroupNumber ASC, Description ASC");
	ReportVariantsTree.GetItems().Clear();
	TreeGroups = New Map;
	TreeGroups.Insert(1, ReportVariantsTree.GetItems());
	
	For Each TableRow IN VariantTable Do
		If Not ValueIsFilled(TableRow.VariantKey) Then
			Continue;
		EndIf;
		TreeRowSet = TreeGroups.Get(TableRow.GroupNumber);
		If TreeRowSet = Undefined Then
			TreeGroup = ReportVariantsTree.GetItems().Add();
			TreeGroup.GroupNumber = TableRow.GroupNumber;
			If TableRow.GroupNumber = 2 Then
				TreeGroup.Description = NStr("en='Hidden in the report panels';ru='Скрытые в панелях отчетов'");
				TreeGroup.PictureIndex = 0;
				TreeGroup.AuthorPicture = -1;
			ElsIf TableRow.GroupNumber = 3 Then
				TreeGroup.Description = NStr("en='Marked for deletion';ru='Помеченные на удаление'");
				TreeGroup.PictureIndex = 1;
				TreeGroup.AuthorPicture = -1;
			EndIf;
			TreeRowSet = TreeGroup.GetItems();
			TreeGroups.Insert(TableRow.GroupNumber, TreeRowSet);
		EndIf;
		
		Variant = TreeRowSet.Add();
		FillPropertyValues(Variant, TableRow);
		If Variant.VariantKey = CurrentVariantKey Then
			Items.ReportVariantsTree.CurrentRow = Variant.GetID();
		EndIf;
		Variant.AuthorPicture = ?(Variant.ForAuthorOnly, -1, 0);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure DeleteVariantOnServer(Ref, PictureIndex)
	VariantObject = Ref.GetObject();
	DeletionMark = Not VariantObject.DeletionMark;
	User = VariantObject.User;
	VariantObject.SetDeletionMark(DeletionMark);
	PictureIndex = ?(DeletionMark, 4, ?(User, 3, 5));
EndProcedure

#EndRegion














