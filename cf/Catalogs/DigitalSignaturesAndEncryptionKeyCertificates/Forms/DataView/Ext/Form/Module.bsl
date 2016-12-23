#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Title = Parameters.DataPresentation;
	
	For Each ItemOfList IN Parameters.ListDataPresentations Do
		FillPropertyValues(List.Add(), ItemOfList);
	EndDo;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenData();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersList

&AtClient
Procedure ListOpen(Command)
	
	OpenData();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenData()
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, Items.List.CurrentData.Value);
	
EndProcedure

#EndRegion














