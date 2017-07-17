////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF SAVING SETTINGS

// Procedure saves the selected item in settings.
//
&AtServer
Procedure SetMainItem()
	
	If Object.Ref <> SmallBusinessReUse.GetValueOfSetting("StatusOfNewPurchaseOrder") Then
		SmallBusinessServer.SetUserSetting(Object.Ref, "StatusOfNewPurchaseOrder");	
		Items.FormCommandSetMainItem.Title = "Used to create new orders";
		Items.FormCommandSetMainItem.Enabled = False;
	EndIf; 
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Ref) Then
		Color = Object.Ref.Color.Get();
		If Object.Ref = SmallBusinessReUse.GetValueOfSetting("StatusOfNewPurchaseOrder") Then
			Items.FormCommandSetMainItem.Title = "Used to create new orders";
			Items.FormCommandSetMainItem.Enabled = False;
		EndIf; 
	Else
		CopyingValue = Undefined;
		Parameters.Property("CopyingValue", CopyingValue);
		If CopyingValue <> Undefined Then
			Color = CopyingValue.Color.Get();
		Else
			Color = New Color(0, 0, 0);
		EndIf;
	EndIf;
	
EndProcedure // OnCreateAtServer()

// Procedure BeforeWriteAtServer
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Color = New Color(0, 0, 0) Then
		CurrentObject.Color = New ValueStorage(Undefined);
	Else
		CurrentObject.Color = New ValueStorage(Color);
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

// Procedure - Command execution handler SetMainItem.
//
&AtClient
Procedure CommandSetMainItem(Command)
	
	If ValueIsFilled(Object.Ref) Then
		SetMainItem();
		Notify("UserSettingsChanged");
	Else
		ShowMessageBox(Undefined,NStr("en='Write the item first.';ru='Элемент необходимо вначале записать!'"));
	EndIf;
	
EndProcedure // CommandSetMainItem()

// Procedure AfterWrite
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_PurchaseOrderStates");
	
EndProcedure // AfterWrite()
// 
