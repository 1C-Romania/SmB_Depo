
#Region FormEventHandlers

&AtClient
Var ResponseBeforeWrite;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then     
		Return;
	EndIf;

	CurrentUser = InfobaseUsers.CurrentUser();

	#If Not WebClient Then
	Object.ComputerName = ComputerName();
	#EndIf
	
	Items.Equipment.Enabled = ValueIsFilled(Object.Ref); 
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If IsBlankString(Object.Code) Then
		SystemInfo = New SystemInfo();
		Object.Code = Upper(SystemInfo.ClientID);
	EndIf;
	
	EquipmentManagerClientServer.FillWorkplaceDescription(Object, CurrentUser);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	place = CurrentObject.Ref;
	
	DeviceList = EquipmentManagerServerCall.GetEquipmentList( , , place);
	For Each Item IN DeviceList Do
		If Item.Workplace = place Then
			LocalEquipment.Add(Item.Ref,Item.Description, False, GetPicture(Item.EquipmentType, 16));
		EndIf;
	EndDo
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not UniquenessCheckByIDClient()Then
		Cancel = True;
		Text = NStr("en='Error workplace saving!
					|Workplace with such client ID already exists.'");
		CommonUseClientServer.MessageToUser(Text);
		Return;
	EndIf;
	
	If Not UniquenessCheckByDescription()Then
		If ResponseBeforeWrite <> True Then
			Cancel = True;
			Text = NStr("en='Nonunique workplace description is specified!
						|It may probably complicate the identification and selection of a workplace in future.
						|It is recommended to specify a unique workplace description.
						|Continue saving with specified description?'");
			Notification = New NotifyDescription("BeforeWriteEnd", ThisObject);
			ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo);
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure BeforeWriteEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ResponseBeforeWrite = True;
		Write();
	EndIf;  
	
EndProcedure 
   
&AtClient
Procedure AfterWrite(WriteParameters)
	
	SystemInfo = New SystemInfo();
	
	If Object.Code = Upper(SystemInfo.ClientID) Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	EquipmentManagerClientServer.FillWorkplaceDescription(Object, CurrentUser);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function UniquenessCheckByDescription()
	
	Result = True;
	
	If Not IsBlankString(Object.Description) Then
		Query = New Query("
		|SELECT
		|    1
		|FROM
		|    Catalog.Workplaces AS Workplaces
		|WHERE
		|    Workplaces.Description = &Description
		|    AND Workplaces.Ref <> &Ref
		|");
		Query.SetParameter("Description", Object.Description);
		Query.SetParameter("Ref"      , Object.Ref);
		Result = Query.Execute().IsEmpty();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function UniquenessCheckByIDClient()
	
	Result = True;
	
	SystemInfo = New SystemInfo();
	ClientID = Upper(SystemInfo.ClientID);
	
	If Not IsBlankString(Object.Code) Then
		Query = New Query("
		|SELECT
		|    1
		|FROM
		|    Catalog.Workplaces AS Workplaces
		|WHERE
		|    Workplaces.Code = &Code
		|    AND Workplaces.Ref <> &Ref
		|");
		Query.SetParameter("Code"    , ClientID);
		Query.SetParameter("Ref" , Object.Ref);
		Result = Query.Execute().IsEmpty();
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function GetPicture(EquipmentType, Size)
	
	Try // Empty reference or undefined can come, there may be no image.
		MetaObject  = EquipmentType.Metadata();
		IndexOf      = Enums.PeripheralTypes.IndexOf(EquipmentType);
		IconName = MetaObject.EnumValues[IndexOf].Name;
		IconName = "Peripherals" + IconName + Size;
		Picture = PictureLib[IconName]
	Except
		Picture = Undefined;
	EndTry;
	
	Return Picture;
	
EndFunction

#EndRegion