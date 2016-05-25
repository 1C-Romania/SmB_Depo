
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ListProductsAndServicesGroups = Parameters.ListProductsAndServicesGroups;
	
EndProcedure

// Fills item presentations and delete empty values.
//
&AtServerNoContext
Procedure FillPresentationOfListItemsServerNoContext(ListProductsAndServicesGroups)
	
	ArrayOfItemsForDeletion = New Array;
	
	For Each ItemOfList IN ListProductsAndServicesGroups Do
	
		If Not ValueIsFilled(ItemOfList.Value) Then
			
			ArrayOfItemsForDeletion.Add(ItemOfList);
			Continue;
			
		EndIf;
		
		ItemOfList.Presentation = ItemOfList.Value.Description;
	
	EndDo;
	
	For Each ArrayElement IN ArrayOfItemsForDeletion Do
	
		ListProductsAndServicesGroups.Delete(ArrayElement);
	
	EndDo;
	
EndProcedure

&AtClient
Procedure CommandOK(Command)
	
	FillPresentationOfListItemsServerNoContext(ListProductsAndServicesGroups);
	Close(ListProductsAndServicesGroups);
	
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
