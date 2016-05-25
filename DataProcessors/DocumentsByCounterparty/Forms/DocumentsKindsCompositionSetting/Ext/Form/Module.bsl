
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
