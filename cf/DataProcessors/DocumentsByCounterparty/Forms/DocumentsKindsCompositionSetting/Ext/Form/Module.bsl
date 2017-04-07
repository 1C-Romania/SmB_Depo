
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	DocumentsKindsList.Clear();
	If Parameters.Property("DocumentsKindsList") Then
		For Each Item IN Parameters.DocumentsKindsList Do

			NewItem = DocumentsKindsList.Add();
			FillPropertyValues(NewItem, Item);

		EndDo;
	EndIf;

EndProcedure

&AtClient
Procedure Save(Command)

	Close(DocumentsKindsList);

EndProcedure
