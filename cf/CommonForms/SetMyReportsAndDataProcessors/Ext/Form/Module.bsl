
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, Parameters, "KindOfDataProcessors, ThisIsGlobalDataProcessors, CurrentSection");
	
	FillTreeOfDataProcessors(True, "MyCommands");
	FillTreeOfDataProcessors(False, "CommandsSource");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	QuestionText = NStr("en='List of the displayed commands was changed.
		|Save changes?';ru='Список выводимых команд был изменен.
		|Сохранить изменения?'");
	Handler = New NotifyDescription("SaveAndInformAboutSelection", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Handler, Cancel, QuestionText);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AddCommand(Command)
	
	CurrentData = Items.CommandsSource.CurrentData;
	
	If CurrentData <> Undefined AND Not IsBlankString(CurrentData.ID) Then
		AddCommandServer(CurrentData.DataProcessor, CurrentData.ID);
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteCommand(Command)
	
	CurrentData = Items.MyCommands.CurrentData;
	
	If CurrentData <> Undefined AND Not IsBlankString(CurrentData.ID) Then
		DeleteCommandServer(CurrentData.DataProcessor, CurrentData.ID);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddAllCommands(Command)
	
	If ThisIsGlobalDataProcessors Then
		CommandsSourceItems = CommandsSource.GetItems();
		
		For Each StringSections IN CommandsSourceItems Do
			ItemSection = FindItemSection(MyCommands, StringSections.Section, StringSections.Description);
			CommandElement = StringSections.GetItems();
			For Each ItemCommand IN CommandElement Do
				NewCommand = FindItemCommand(ItemSection.GetItems(), ItemCommand.ID);
				FillPropertyValues(NewCommand, ItemCommand);
			EndDo;
		EndDo;
	Else
		AddAllCommandsServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteAllCommands(Command)
	
	MyCommands.GetItems().Clear();
	
EndProcedure

&AtClient
Procedure OK(Command)
	WriteSetOfUserDataProcessors();
	NotifyChoice("ExecutedMyReportsAndDataProcessorsCustomization");
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SaveAndInformAboutSelection(Result, AdditionalParameters) Export
	
	WriteSetOfUserDataProcessors();
	NotifyChoice("ExecutedMyReportsAndDataProcessorsCustomization");
	
EndProcedure

&AtServer
Function FillTreeOfDataProcessors(UserCommands, NameAttributeItemsOfTree)
	
	Query = New Query;
	
	QueryText = 
	"SELECT
	|	AdditionalReportsAndDataProcessors.Ref AS DataProcessor,
	|	CommandTable.Presentation AS Description,
	|	SectionsTable.Section AS Section,
	|	CommandTable.ID AS ID
	|FROM
	|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
	|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS CommandTable
	|		ON AdditionalReportsAndDataProcessors.Ref = CommandTable.Ref
	|		INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Sections AS SectionsTable
	|		ON AdditionalReportsAndDataProcessors.Ref = SectionsTable.Ref
	|		LEFT JOIN InformationRegister.UserSettingsOfAccessToDataProcessors AS QuickAccess
	|		ON AdditionalReportsAndDataProcessors.Ref = QuickAccess.AdditionalReportOrDataProcessor
	|			AND (QuickAccess.CommandID = CommandTable.ID)
	|			AND (QuickAccess.User = &User)
	|WHERE
	|	AdditionalReportsAndDataProcessors.Type = &KindOfDataProcessors
	|	AND Not AdditionalReportsAndDataProcessors.DeletionMark
	|	AND AdditionalReportsAndDataProcessors.Publication IN(&PublicationVariants)
	|	AND QuickAccess.Available
	|TOTALS BY
	|	&TotalsBySection";
	
	If ThisIsGlobalDataProcessors Then
		QueryText = StrReplace(QueryText, "&TotalsBySection", "Section");
	Else
		QueryText = StrReplace(QueryText, "SectionsTable.Section AS Section,", "");
		QueryText = StrReplace(QueryText, "INNER JOIN Catalog.AdditionalReportsAndDataProcessors.Sections AS SectionsTable", "");
		QueryText = StrReplace(QueryText, "ON AdditionalReportsAndDataProcessors.Ref = SectionsTable.Ref", "");
		QueryText = StrReplace(QueryText, "TOTALS BY", "");
		QueryText = StrReplace(QueryText, "&TotalsBySection", "");
	EndIf;
	
	If Not UserCommands Then
		QueryText = StrReplace(QueryText, "LEFT JOIN InformationRegister.UserSettingsOfAccessToDataProcessors AS QuickAccess", "");
		QueryText = StrReplace(QueryText, "ON AdditionalReportsAndDataProcessors.Ref = QuickAccess.AdditionalReportOrDataProcessor", "");
		QueryText = StrReplace(QueryText, "AND (QuickAccess.CommandID = CommandTable.ID)", "");
		QueryText = StrReplace(QueryText, "AND (QuickAccess.User = &User)", "");
		QueryText = StrReplace(QueryText, "AND QuickAccess.Available", "");
	EndIf;
	
	PublicationVariants = New Array;
	PublicationVariants.Add(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	If Users.RolesAvailable("AddChangeAdditionalReportsAndDataProcessors") Then
		PublicationVariants.Add(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode);
	EndIf;
	
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("PublicationVariants", PublicationVariants);
	Query.SetParameter("KindOfDataProcessors", KindOfDataProcessors);
	
	Query.Text = QueryText;
	
	If ThisIsGlobalDataProcessors Then
		TreeCommand = Query.Execute().Unload(QueryResultIteration.ByGroups);
	Else
		CommandTable = Query.Execute().Unload();
	EndIf;
	
	CommandsTree = FormAttributeToValue(NameAttributeItemsOfTree);
	CommandsTree.Rows.Clear();
	
	OwnIndex = 0;
	IndexOf = 0;
	
	If ThisIsGlobalDataProcessors Then
		For Each StringSections IN TreeCommand.Rows Do
			PresentationOfSection = AdditionalReportsAndDataProcessors.PresentationOfSection(StringSections.Section);
			If PresentationOfSection = Undefined Then
				Continue;
			EndIf;
			UpperLevelRow = CommandsTree.Rows.Add();
			UpperLevelRow.Section = StringSections.Section;
			UpperLevelRow.Description = PresentationOfSection;
			If UpperLevelRow.Section = CurrentSection Then
				OwnIndex = IndexOf;
			EndIf;
			For Each CommandString IN StringSections.Rows Do
				CommandsDescriptionRow = UpperLevelRow.Rows.Add();
				FillPropertyValues(CommandsDescriptionRow, CommandString);
				IndexOf = IndexOf + 1;
			EndDo;
			IndexOf = IndexOf + 1;
		EndDo;
	Else
		For Each ItemCommand IN CommandTable Do
			NewRow = CommandsTree.Rows.Add();
			FillPropertyValues(NewRow, ItemCommand);
		EndDo;
	EndIf;
	
	ValueToFormAttribute(CommandsTree, NameAttributeItemsOfTree);
	
	Items[NameAttributeItemsOfTree].CurrentRow = OwnIndex;
	
EndFunction

&AtServer
Procedure AddCommandServer(DataProcessor, ID)
	
	MyCommandsTree = FormAttributeToValue("MyCommands");
	FoundStrings = MyCommandsTree.Rows.FindRows(New Structure("DataProcessor,ID", DataProcessor, ID), True);
	If FoundStrings.Count() > 0 Then
		Return;
	EndIf;
	
	CommandsSourceTree = FormAttributeToValue("CommandsSource");
	FoundStrings = CommandsSourceTree.Rows.FindRows(New Structure("DataProcessor,ID", DataProcessor, ID), True);
		
	If ThisIsGlobalDataProcessors Then	
		For Each FoundString IN FoundStrings Do
			ItemSection = FindItemSection(MyCommands, FoundString.Section, FoundString.Parent.Description);
			NewCommand = ItemSection.GetItems().Add();
			FillPropertyValues(NewCommand, FoundString);
		EndDo;
	Else
		NewCommand = MyCommands.GetItems().Add();
		FillPropertyValues(NewCommand, FoundStrings[0]);
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAllCommandsServer()
	
	ValueToFormAttribute(FormAttributeToValue("CommandsSource"), "MyCommands");
	
EndProcedure

&AtServer
Procedure DeleteCommandServer(DataProcessor, ID)
	
	MyCommandsItems = MyCommands.GetItems();
	
	If ThisIsGlobalDataProcessors Then
		
		DeletingSections = New Array;
		
		For Each StringSections IN MyCommandsItems Do
			CommandElement = StringSections.GetItems();
			For Each CommandString IN CommandElement Do
				If CommandString.DataProcessor = DataProcessor AND CommandString.ID = ID Then
					CommandElement.Delete(CommandElement.IndexOf(CommandString));
					Break;
				EndIf;
			EndDo;
			If CommandElement.Count() = 0 Then
				DeletingSections.Add(MyCommandsItems.IndexOf(StringSections));
			EndIf;
		EndDo;
		
		DeletingSectionsTable = New ValueTable;
		DeletingSectionsTable.Columns.Add("Section", New TypeDescription("Number",New NumberQualifiers(10)));
		For Each DeletingSection IN DeletingSections Do
			String = DeletingSectionsTable.Add();
			String.Section = DeletingSection;
		EndDo;
		DeletingSectionsTable.GroupBy("Section");
		DeletingSectionsTable.Sort("Section Desc");
		
		DeletingSections = DeletingSectionsTable.UnloadColumn("Section");
		
		For Each DeletingSection IN DeletingSections Do
			MyCommandsItems.Delete(DeletingSection);
		EndDo;
		
	Else
		
		For Each CommandString IN MyCommandsItems Do
			If CommandString.DataProcessor = DataProcessor AND CommandString.ID = ID Then
				MyCommandsItems.Delete(MyCommandsItems.IndexOf(CommandString));
				Break;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function FindItemSection(FormDataCommand, Section, Description)
	
	Result = Undefined;
	
	For Each DataItem IN FormDataCommand.GetItems() Do
		If DataItem.Section = Section Then
			Result = DataItem;
			Break;
		EndIf;
	EndDo;
	
	If Result = Undefined Then
		NewSection = FormDataCommand.GetItems().Add();
		NewSection.Section = Section;
		NewSection.Description = Description;
		Result = NewSection;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function FindItemCommand(FormDataTreeItemCollection, ID)
	
	Result = Undefined;
	
	For Each DataItem IN FormDataTreeItemCollection Do
		If DataItem.ID = ID Then
			Result = DataItem;
			Break;
		EndIf;
	EndDo;
	
	If Result = Undefined Then
		NewSection = FormDataTreeItemCollection.Add();
		Result = NewSection;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with the register UserSettingsOfAccessToDataProcessors.

&AtServer
Procedure WriteSetOfUserDataProcessors()
	
	QueryText = "
			|SELECT
			|	AdditionalReportsAndDataProcessorsCommands.ID AS ID,
			|	AdditionalReportsAndDataProcessors.Ref				AS DataProcessor
			|FROM
			|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
			|	JOIN Catalog.AdditionalReportsAndDataProcessors.Commands AS AdditionalReportsAndDataProcessorsCommands
			|			ON AdditionalReportsAndDataProcessorsCommands.Ref = AdditionalReportsAndDataProcessors.Ref
			|WHERE
			|	AdditionalReportsAndDataProcessors.Type = &KindOfDataProcessors";
	
	Query = New Query;
	Query.Parameters.Insert("KindOfDataProcessors", KindOfDataProcessors);
	Query.Text = QueryText;
	
	DataProcessorTable = Query.Execute().Unload();
	
	MyCommandsTree = FormAttributeToValue("MyCommands");
	
	TableOfMyCommands = GetTable();
	
	If ThisIsGlobalDataProcessors Then
		For Each StringSections IN MyCommandsTree.Rows Do
			For Each CommandString IN StringSections.Rows Do
				NewRow = TableOfMyCommands.Add();
				FillPropertyValues(NewRow, CommandString);
			EndDo;
		EndDo;
	Else
		For Each CommandString IN MyCommandsTree.Rows Do
			NewRow = TableOfMyCommands.Add();
			FillPropertyValues(NewRow, CommandString);
		EndDo;
	EndIf;
	
	TableOfMyCommands.GroupBy("DataProcessor,ID");
	
	// ----------------
	
	ComparisonTable = DataProcessorTable.Copy();
	ComparisonTable.Columns.Add("SignOf", New TypeDescription("Number", New NumberQualifiers(1)));
	For Each String IN ComparisonTable Do
		String.SignOf = -1;
	EndDo;
	
	For Each String IN TableOfMyCommands Do
		NewRow = ComparisonTable.Add();
		FillPropertyValues(NewRow, String);
		NewRow.SignOf = +1;
	EndDo;
	
	ComparisonTable.GroupBy("DataProcessor,ID", "SignOf");
	
	RowsForExceptionsFromListOfOwn = ComparisonTable.FindRows(New Structure("SignOf", -1));
	RowsForAddToOwnList = ComparisonTable.FindRows(New Structure("SignOf", 0));
	
	BeginTransaction();
	
	Try
		AdditionalReportsAndDataProcessors.DeleteCommandsFromOwnList(RowsForExceptionsFromListOfOwn);
		AdditionalReportsAndDataProcessors.AddCommandsToOwnList(RowsForAddToOwnList);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Modified = False;
EndProcedure

&AtServerNoContext
Function GetTable()
	
	CommandTable = New ValueTable;
	CommandTable.Columns.Add("DataProcessor", New TypeDescription("CatalogRef.AdditionalReportsAndDataProcessors"));
	CommandTable.Columns.Add("ID", New TypeDescription("String"));
	
	Return CommandTable;
	
EndFunction

#EndRegion
