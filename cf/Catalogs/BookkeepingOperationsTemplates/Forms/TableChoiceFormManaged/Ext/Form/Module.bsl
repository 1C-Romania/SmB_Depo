
#Region BaseFormsProcedures

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	DocumentBase = ?(Parameters.Property("DocumentBase"), Parameters.DocumentBase, Undefined);
	DocumentTableSynonym = ?(Parameters.Property("DocumentTableSynonym"), Parameters.DocumentTableSynonym, Undefined);
	TableKind = ?(Parameters.Property("TableKind"), Parameters.TableKind, Enums.BookkeepingOperationTemplateTableKind.EmptyRef());	
	TableKindFilter = ?(Parameters.Property("TableKindFilter"), Parameters.TableKindFilter, New ValueList);
	TableName = ?(Parameters.Property("TableName"), Parameters.TableName, "");
	GoToCurrentRow = ?(Parameters.Property("GoToCurrentRow"), Parameters.GoToCurrentRow, "");	
	DontAllowToCheckBoxShowOnlyAvailable = ?(Parameters.Property("DontAllowToCheckBoxShowOnlyAvailable"), Parameters.DontAllowToCheckBoxShowOnlyAvailable, "");		
	
	CurrentSelectedTables = ?(Parameters.Property("CurrentSelectedTables"), Parameters.CurrentSelectedTables, Undefined);	
	
	CurrentTableList = Catalogs.BookkeepingOperationsTemplates.GetListOfAvailableTables(CurrentSelectedTables,DocumentTableSynonym,TableKindFilter,TableName,DocumentBase);	
	ValueToFormAttribute(CurrentTableList,"TablesList");
	ValueToFormAttribute(CurrentTableList,"TablesListSource");	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If DontAllowToCheckBoxShowOnlyAvailable Then
		Items.CheckBoxShowOnlyAvailable.Visible = False;
	EndIf;	
	
	For Each Row In TablesList.GetItems() Do
		Items.TablesList.Expand(Row.GetID(),True);
	EndDo;	
	
	If GoToCurrentRow 
		AND TablesList.GetItems().Count() > 0 Then
		
		CurrentRow = FindCurrentRow(TablesList);
		If CurrentRow<>Undefined Then
			
			Items.TablesList.CurrentRow = CurrentRow;
			
		EndIf;
		
	EndIf;
EndProcedure

#EndRegion

#Region FormsCommands

&AtClient
Procedure CommandOK(Command)
	SelectRow(Items.TablesList.CurrentData);
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure CheckBoxShowOnlyAvailableOnChange(Item)
	CheckBoxShowOnlyAvailableOnChangeAtServer();
	
	For Each Row In TablesList.GetItems() Do
		Items.TablesList.Expand(Row.GetID(),True);
	EndDo;	
EndProcedure

&AtServer
Procedure CheckBoxShowOnlyAvailableOnChangeAtServer()
	RefillTableList(TablesListSource.GetItems(), TablesList.GetItems());
EndProcedure

&AtClient
Procedure TablesListSelection(Item, SelectedRow, Field, StandardProcessing)
	SelectRow(Items.TablesList.CurrentData);
EndProcedure

#EndRegion

#Region Other

&AtClient
Procedure SelectRow(SelectedRow)
	
	If SelectedRow <> Undefined AND SelectedRow.GetItems().Count() = 0 AND SelectedRow.Availability <> False Then
		
		ReturnStructure = New Structure("TableName, TableKind, TableSynonym, TablePicture", SelectedRow.TableName, SelectedRow.TableKind, SelectedRow.TableSynonym, SelectedRow.TablePicture);
		Close(ReturnStructure);
		
	Else
		
		If SelectedRow.Availability = False Then
			
			ShowMessageBox( , Nstr("en = 'Current table was already selected!'; pl = 'Wybrana tabela już została wybrana!'"));
			
		Else	
		
			ShowMessageBox( , Nstr("en = 'Current row is a group and could not be selected!'; pl = 'Wybrany wiersz jest grupą i nie może być wybrany!'"));
			
		EndIf;

	EndIf;	
	
EndProcedure

&AtClient
Function FindCurrentRow(Item)
	CurrentRow = Undefined;
	For Each Row In Item.GetItems() Do
		CurrentRow = FindCurrentRow(Row);
		If CurrentRow <> Undefined Then
			Return CurrentRow;
	    ElsIf Row.TableName=TableName And Row.TableKind = TableKind Then
			Return Row.GetId();
		EndIf;		
	EndDo;
	Return Undefined;
EndFunction

&AtServer
Procedure RefillTableList(RowsSource,RowsDestination)	
	RowsDestination.Clear();
	
	For Each Row In RowsSource Do
		
		If CheckBoxShowOnlyAvailable AND Row.Availability = False Then
		
			Continue;
			
		Else
			
			NewRow = RowsDestination.Add();
			FillPropertyValues(NewRow,Row);
			
			If Row.GetItems().Count()>0 Then
				
				RefillTableList(Row.GetItems(),NewRow.GetItems());
				
			EndIf;	
			
		EndIf;
		
	EndDo;	
	
EndProcedure	
#EndRegion