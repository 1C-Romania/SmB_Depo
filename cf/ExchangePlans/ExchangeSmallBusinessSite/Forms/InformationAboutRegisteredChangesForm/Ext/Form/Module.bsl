
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExchangeNode = Parameters.ExchangeNode;
	
	If ExchangeNode = ExchangePlans.ExchangeSmallBusinessSite.ThisNode() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	ChangesTreeRefreshServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ChangesTree.GetItems().Count() = 0 Then
		
		ShowUserNotification(
			NStr("en='The changes are not registered';ru='Изменения не зарегистрированы.'")
			,,,
			PictureLib.Information32);
			
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangesTreeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure Refresh(Command)
	ChangesTreeRefreshServer();
EndProcedure

&AtServer
Procedure ChangesTreeRefreshServer()
	
	ChangesStructure = New Structure;
	ExchangeWithSite.FillChangesStructureForNode(ExchangeNode, ChangesStructure);
	
	TreeRows = ChangesTree.GetItems();
	TreeRows.Clear();
	
	If ChangesStructure.Products.Count() > 0 Then
		
		TreeRow = TreeRows.Add();
		TreeRow.ObjectKind = NStr("en='Products';ru='Товары'");
	
		For Each ArrayElement IN ChangesStructure.Products Do
			ObjectString = TreeRow.GetItems().Add();
			ObjectString.Object = ArrayElement;
		EndDo;
		
	EndIf;
	
	If ChangesStructure.Files.Count() > 0 Then
		
		TreeRow = TreeRows.Add();
		TreeRow.ObjectKind = NStr("en='Files';ru='Файлы'");
		
		For Each ArrayElement IN ChangesStructure.Files Do
			ObjectString = TreeRow.GetItems().Add();
			ObjectString.Object = ArrayElement;
		EndDo;
		
	EndIf;
	
	If ChangesStructure.Orders.Count() > 0 Then
		
		TreeRow = TreeRows.Add();
		TreeRow.ObjectKind = NStr("en='Orders';ru='заказы'");
		
		For Each ArrayElement IN ChangesStructure.Orders Do
			ObjectString = TreeRow.GetItems().Add();
			ObjectString.Object = ArrayElement;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TreeObjectClear(Item, StandardProcessing)
	
	Parent = Items.ChangesTree.CurrentData.GetParent();
	
	If Parent = UNDEFINED Then
		Return;
	EndIf;
	
	RegistrationDeleteServer(Items.ChangesTree.CurrentData.Object);
	Parent.GetItems().Delete(Items.ChangesTree.CurrentData);
	
EndProcedure

&AtServer
Procedure RegistrationDeleteServer(DataRef);
	
	ExchangePlans.DeleteChangeRecords(ExchangeNode, DataRef);
	
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
