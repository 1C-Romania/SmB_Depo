#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ListColumns = Parameters.ListColumns;
	ListColumns.SortByPresentation();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Selection(Command)
	Close(ListColumns);
EndProcedure

#EndRegion

#Region TableItemsSelectionEventHandlers

&AtClient
Procedure ColumnsListChoice(Item, SelectedRow, Field, StandardProcessing)
	ListColumns.FindByID(SelectedRow).Check = Not ListColumns.FindByID(SelectedRow).Check;
EndProcedure

#EndRegion