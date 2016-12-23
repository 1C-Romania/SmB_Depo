////////////////////////////////////////////////////////////////////////////////
// FORM EVENTS

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, Parameters, "VariantRef, ReportRef, SubsystemRef, ReportDescription");
	Items.GroupOtherReportVariants.Title = ReportName + " (" + NStr("en='Report variants';ru='Варианты отчета'") + "):";
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		ReportVariantsGroupsColour = StyleColors.ReportsVariantsGroupColor82;
		CommonGroupFont = New Font("MS Shell Dlg", 8, True, False, False, False, 100);
	Else // Taxi.
		ReportVariantsGroupsColour = StyleColors.ReportsVariantsGroupColor;
		CommonGroupFont = New Font("Arial", 12, False, False, False, False, 90);
	EndIf;
	Items.GroupOtherReportVariants.TitleTextColor = ReportVariantsGroupsColour;
	Items.GroupOtherReportVariants.TitleFont = CommonGroupFont;
	
	ReadThisFormsSettings();
	
	WindowOptionsKey = String(VariantRef.UUID()) + "\" + String(SubsystemRef.UUID());
	
	FillReportsPanel();
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// ITEMS EVENTS

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CloseThisWindowAfterTransitionToReportOnChange(Item)
	SaveThisFormSettings();
EndProcedure

&AtClient
Procedure VariantPress(Item)
	Found = PanelVariants.FindRows(New Structure("TitleName", Item.Name));
	If Found.Count() <> 1 Then
		Return;
	EndIf;
	Variant = Found[0];
	
	OpenParameters = New Structure;
	OpenParameters.Insert("VariantKey", Variant.VariantKey);
	OpenParameters.Insert("Subsystem",   SubsystemRef);
	
	// Open
	If Variant.Additional Then
		
		OpenParameters.Insert("Variant",      Variant.Ref);
		OpenParameters.Insert("Report",        Variant.Report);
		ReportsVariantsClient.OpenAdditionalReportVariants(OpenParameters);
		
	ElsIf Not ValueIsFilled(Variant.ReportName) Then
		
		WarningText = StrReplace(NStr("en='Report name for option ""%1"" is not filled in.';ru='Не заполнено имя отчета для варианта ""%1"".'"), "%1", Variant.Description);
		ShowMessageBox(, WarningText);
		Return;
		
	Else
		
		Uniqueness = "Report." + Variant.ReportName;
		If ValueIsFilled(Variant.VariantKey) Then
			Uniqueness = Uniqueness + "/VariantKey." + Variant.VariantKey;
		EndIf;
		
		OpenParameters.Insert("PrintParametersKey", Uniqueness);
		OpenParameters.Insert("WindowOptionsKey", Uniqueness);
		
		OpenForm("Report." + Variant.ReportName + ".Form", OpenParameters, Undefined, True);
		
	EndIf;
	
	If CloseAfterSelection Then
		Close();
	EndIf;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// HELPER PROCEDURE AND FUNCTIONS

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Server call, Server

&AtServer
Procedure SaveThisFormSettings()
	FormSettings = DefaultSettings();
	FillPropertyValues(FormSettings, ThisObject);
	CommonUse.FormDataSettingsStorageSave(
		ReportsVariantsClientServer.SubsystemFullName(),
		"OtherReportsPanel", 
		FormSettings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure ReadThisFormsSettings()
	DefaultSettings = DefaultSettings();
	Items.CloseAfterSelection.Visible = DefaultSettings.ShowCheckBox;
	FormSettings = CommonUse.CommonSettingsStorageImport(
		ReportsVariantsClientServer.SubsystemFullName(),
		"OtherReportsPanel",
		DefaultSettings);
	FillPropertyValues(ThisObject, FormSettings);
EndProcedure

&AtServer
Function DefaultSettings()
	Return ReportsVariants.GlobalSettings().OtherReports;
EndFunction

&AtServer
Procedure FillReportsPanel()
	ThereAreOtherReports = False;
	
	OutputTable = FormAttributeToValue("PanelVariants");
	OutputTable.Columns.Add("ItemShouldBeAdded", New TypeDescription("Boolean"));
	OutputTable.Columns.Add("ItemShouldBeLeft", New TypeDescription("Boolean"));
	OutputTable.Columns.Add("Group");
	
	QueryText =
	"SELECT ALLOWED
	|	ReportsVariants.Ref,
	|	ReportsVariants.Report,
	|	ReportsVariants.VariantKey,
	|	ReportsVariants.Description AS Description,
	|	CASE
	|		WHEN SubString(ReportsVariants.Definition, 1, 1) = """"
	|			THEN CAST(ReportsVariants.PredefinedVariant.Definition AS String(1000))
	|		ELSE CAST(ReportsVariants.Definition AS String(1000))
	|	END AS Definition,
	|	ReportsVariants.Author,
	|	ReportsVariants.ReportType,
	|	ReportsVariants.Report.Name AS ReportName
	|FROM
	|	Catalog.ReportsVariants AS ReportsVariants
	|WHERE
	|	ReportsVariants.Report = &Report
	|	AND ReportsVariants.DeletionMark = FALSE
	|	AND (ReportsVariants.ForAuthorOnly = FALSE
	|			OR ReportsVariants.Author = &CurrentUser)
	|	AND Not ReportsVariants.PredefinedVariant IN (&DisabledApplicationOptions)
	|	AND ReportsVariants.VariantKey <> """"
	|
	|ORDER BY
	|	Description";
	
	Query = New Query;
	Query.SetParameter("Report", ReportRef);
	Query.SetParameter("CurrentUser", Users.CurrentUser());
	Query.SetParameter("DisabledApplicationOptions", ReportsVariantsReUse.DisabledApplicationOptions());
	Query.Text = QueryText;
	
	CommonSettings = ReportsVariants.CommonPanelSettings();
	ShowToolTips = CommonSettings.ShowToolTips = 1;
	
	VariantTable = Query.Execute().Unload();
	For Each TableRow IN VariantTable Do
		// Only other variants.
		If TableRow.Ref = VariantRef Then
			Continue;
		EndIf;
		ThereAreOtherReports = True;
		DisplayHyperlinkOnPanel(OutputTable, TableRow, Items.GroupOtherReportVariants, ShowToolTips);
	EndDo;
	Items.GroupOtherReportVariants.Visible = (VariantTable.Count() > 0);
	
	RelatedReportsGroupVisible = False;
	If ValueIsFilled(SubsystemRef) Then
		Subsystems = Subsystems();
		
		SearchParameters = New Structure;
		SearchParameters.Insert("Subsystems", Subsystems);
		SearchParameters.Insert("OnlyVisibleInReportPanel", True);
		SearchParameters.Insert("ReceiveSummaryTable", True);
		SearchParameters.Insert("DeletionMark", False);
		
		SearchResult = ReportsVariants.FindReferences(SearchParameters);
		
		VariantTable = SearchResult.ValueTable;
		VariantTable.Columns.VariantName.Name = "Description";
		VariantTable.Sort("Description");
		
		// Delete the strings matching current version (opened at the moment).
		Found = VariantTable.FindRows(New Structure("Ref", VariantRef));
		For Each TableRow IN Found Do
			VariantTable.Delete(TableRow);
		EndDo;
		
		// Subsystems bypass and output of found options.
		For Each SubsystemRef IN Subsystems Do
			Found = VariantTable.FindRows(New Structure("Subsystem", SubsystemRef));
			If Found.Count() = 0 Then
				Continue;
			EndIf;
			
			Group = DetectOutputGroup(Found[0].SubsystemDescription);
			For Each TableRow IN Found Do
				ThereAreOtherReports = True;
				DisplayHyperlinkOnPanel(OutputTable, TableRow, Group, ShowToolTips);
			EndDo;
		EndDo;
	EndIf;
	
	// PanelVariantsItemNumber
	FoundForDeletion = OutputTable.FindRows(New Structure("ItemShouldBeLeft", False));
	For Each TableRow IN FoundForDeletion Do
		VariantItem = Items.Find(TableRow.TitleName);
		If VariantItem <> Undefined Then
			Items.Delete(VariantItem);
		EndIf;
		OutputTable.Delete(TableRow);
	EndDo;
	
	OutputTable.Columns.Delete("ItemShouldBeLeft");
	OutputTable.Columns.Delete("Group");
	ValueToFormAttribute(OutputTable, "PanelVariants");
EndProcedure

&AtServer
Procedure DisplayHyperlinkOnPanel(OutputTable, Variant, Group, ShowToolTips)
	
	Found = OutputTable.FindRows(New Structure("Ref, Group", Variant.Ref, Group.Name));
	If Found.Count() > 0 Then
		OutputString = Found[0];
		OutputString.ItemShouldBeLeft = True;
		Return;
	EndIf;
	
	OutputString = OutputTable.Add();
	FillPropertyValues(OutputString, Variant);
	PanelVariantsItemNumber = PanelVariantsItemNumber + 1;
	OutputString.TitleName = "Variant" + Format(PanelVariantsItemNumber, "NG=");
	OutputString.Additional = (Variant.ReportType = Enums.ReportsTypes.Additional);
	OutputString.GroupName = Group.Name;
	OutputString.ItemShouldBeLeft = True;
	OutputString.Group = Group;
	
	// Adding label-hyperlink of the report variant.
	Label = Items.Insert(OutputString.TitleName, Type("FormDecoration"), OutputString.Group);
	Label.Type = FormDecorationType.Label;
	Label.Hyperlink = True;
	Label.HorizontalStretch = True;
	Label.VerticalStretch = False;
	Label.Height = 1;
	Label.TextColor = StyleColors.VisibleReportOptionColor;
	Label.Title = TrimAll(String(Variant.Ref));
	If ValueIsFilled(Variant.Definition) Then
		Label.ToolTip = TrimAll(Variant.Definition);
	EndIf;
	If ValueIsFilled(Variant.Author) Then
		Label.ToolTip = TrimL(Label.ToolTip + Chars.LF) + NStr("en='Author:';ru='Автор:'") + " " + TrimAll(String(Variant.Author));
	EndIf;
	If ShowToolTips Then
		Label.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
		Label.ExtendedTooltip.HorizontalStretch = True;
		Label.ExtendedTooltip.TextColor = StyleColors.ExplanationText;
	EndIf;
	Label.SetAction("Click", "VariantPress");
	
EndProcedure

&AtServer
Function Subsystems()
	Result = New Array;
	Result.Add(SubsystemRef);
	
	SubsystemsTree = ReportsVariantsReUse.CurrentUserSubsystems();
	Found = SubsystemsTree.Rows.FindRows(New Structure("Ref", SubsystemRef), True);
	While Found.Count() > 0 Do
		RowCollection = Found[0].Rows;
		Found.Delete(0);
		For Each TreeRow IN RowCollection Do
			Result.Add(TreeRow.Ref);
			Found.Add(TreeRow);
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function DetectOutputGroup(SubsystemPresentation)
	ItemOfList = SubsystemsGroups.FindByValue(SubsystemPresentation);
	If ItemOfList <> Undefined Then
		Return Items.Find(ItemOfList.Presentation);
	EndIf;
	
	GroupNumber = SubsystemsGroups.Count() + 1;
	DecorationName = "SubsystemIndent_" + GroupNumber;
	GroupName    = "GroupSubsystems_" + GroupNumber;
	
	If ThereAreOtherReports Then
		Decoration = Items.Add(DecorationName, Type("FormDecoration"), Items.PageOtherReports);
		Decoration.Type = FormDecorationType.Label;
		Decoration.Title = " ";
	EndIf;
	
	Group = Items.Add(GroupName, Type("FormGroup"), Items.PageOtherReports);
	Group.Type = FormGroupType.UsualGroup;
	Group.Title = SubsystemPresentation;
	Group.ShowTitle = True;
	Group.TitleTextColor = ReportVariantsGroupsColour;
	Group.TitleFont = CommonGroupFont;
	
	SubsystemsGroups.Add(SubsystemPresentation, GroupName);
	Return Group;
EndFunction

#EndRegion














