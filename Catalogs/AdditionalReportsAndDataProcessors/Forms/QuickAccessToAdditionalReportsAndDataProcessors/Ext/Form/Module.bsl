#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Quick access to command ""%1""';ru='Быстрый доступ к команде ""%1""'"),
		Parameters.CommandPresentation);
	
	FillTables();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersAllUsers

&AtClient
Procedure AllUsersDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(AllUsers, UsersOfShortList, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure AllUsersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersShortListUsers

&AtClient
Procedure ShortListUsersDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	If TypeOf(DragParameters.Value[0]) = Type("Number") Then
		Return;
	EndIf;
	
	MoveUsers(UsersOfShortList, AllUsers, DragParameters.Value);
	
EndProcedure

&AtClient
Procedure ShortListUsersDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RemoveAccessToCommandFromAllUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each RowDetails IN UsersOfShortList Do
		ArrayOfDruggedItems.Add(RowDetails);
	EndDo;
	
	MoveUsers(AllUsers, UsersOfShortList, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure RemoveAccessToCommandFromSelectedUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each SelectedRow IN Items.UsersOfShortList.SelectedRows Do
		ArrayOfDruggedItems.Add(Items.UsersOfShortList.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(AllUsers, UsersOfShortList, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure SetAccessForAllUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each RowDetails IN AllUsers Do
		ArrayOfDruggedItems.Add(RowDetails);
	EndDo;
	
	MoveUsers(UsersOfShortList, AllUsers, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure SetCommandForSelectedUsers(Command)
	
	ArrayOfDruggedItems = New Array;
	
	For Each SelectedRow IN Items.AllUsers.SelectedRows Do
		ArrayOfDruggedItems.Add(Items.AllUsers.RowData(SelectedRow));
	EndDo;
	
	MoveUsers(UsersOfShortList, AllUsers, ArrayOfDruggedItems);
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New ValueList;
	
	For Each CollectionItem IN UsersOfShortList Do
		ChoiceResult.Add(CollectionItem.User);
	EndDo;
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillTables()
	SelectedList = Parameters.UsersWithFastAccess;
	Query = New Query("SELECT Ref FROM Catalog.Users WHERE Not DeletionMark AND Not NotValid");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If SelectedList.FindByValue(Selection.Ref) = Undefined Then
			AllUsers.Add().User = Selection.Ref;
		Else
			UsersOfShortList.Add().User = Selection.Ref;
		EndIf;
	EndDo;
	AllUsers.Sort("User Asc");
	UsersOfShortList.Sort("User Asc");
EndProcedure

&AtClient
Procedure MoveUsers(Receiver, Source, ArrayOfDruggedItems)
	
	For Each DraggedItem IN ArrayOfDruggedItems Do
		NewUser = Receiver.Add();
		NewUser.User = DraggedItem.User;
		Source.Delete(DraggedItem);
	EndDo;
	
	Receiver.Sort("User Asc");
	
EndProcedure

#EndRegion



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
