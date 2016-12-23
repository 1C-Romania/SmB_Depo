&AtClient
Var RefreshInterface;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// StandardSubsystems.FileFunctions
	MaximumFileSize              = FileFunctions.MaximumFileSizeCommon() / (1024*1024);
	If RunMode.SaaS Then
		Items.MaximumFileSize.MaxValue = MaximumFileSize;
	EndIf;
	// End StandardSubsystems.FileFunctions
	
EndProcedure

&AtClient
Procedure OnClose()
	RefreshApplicationInterface();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

////////////////////////////////////////////////////////////////////////////////
// Common parameters for all data areas

// StandardSubsystems.FileFunctions
&AtClient
Procedure MaximumFileSizeOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure ProhibitedExtensionsListOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure

&AtClient
Procedure FileExtensionsListOpenDocumentOnChange(Item)
	Attachable_OnAttributeChange(Item);
EndProcedure
// End StandardSubsystems.FileFunctions

#EndRegion

#Region FormCommandsHandlers

#EndRegion

#Region ServiceProceduresAndFunctions

// StandardSubsystems.FileFunctions
&AtClient
Procedure StoreFilesInVolumesOnDiskOnChangeEnd(Response, Item) Export
	
	If Response <> DialogReturnCode.OK Then
		ConstantsSet.StoreFilesInVolumesOnHardDisk = Not ConstantsSet.StoreFilesInVolumesOnHardDisk;
	Else
		Attachable_OnAttributeChange(Item);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FileFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	RefreshReusableValues();
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
		
		// StandardSubsystems.FileFunctions
		If AttributePathToData = "MaximumFileSize" Then
			ConstantsSet.MaximumFileSize = MaximumFileSize * (1024*1024);
			ConstantName = "MaximumFileSize";
		ElsIf AttributePathToData = "MaxDataAreaFileSize" Then
			If RunMode.Local Or RunMode.Standalone Then
				ConstantsSet.MaximumFileSize = MaxDataAreaFileSize * (1024*1024);
				ConstantName = "MaximumFileSize";
			Else
				ConstantsSet.MaxDataAreaFileSize = MaxDataAreaFileSize * (1024*1024);
				ConstantName = "MaxDataAreaFileSize";
			EndIf;
		EndIf;
		// End StandardSubsystems.FileFunctions
		
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
EndProcedure

#EndRegion














