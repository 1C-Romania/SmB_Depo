#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns the list of attributes allowed to be changed
// with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// Updates the description content
// of predefined sets in additional attributes and data parameters.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if there
//               is a record, True is set, otherwise, it is not changed.
//
Procedure RefreshContentOfPredefinedSets(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	PredefinedSets = PredefinedSets();
	
	Block = New DataLock;
	LockItem = Block.Add("Constant.AdditionalAttributesAndInformationParameters");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Parameters = StandardSubsystemsServer.ApplicationWorkParameters(
			"AdditionalAttributesAndInformationParameters");
		
		HasDeleted = False;
		Saved = Undefined;
		
		If Parameters.Property("PredefinedSetsOfAdditionalDetailsAndInformation") Then
			Saved = Parameters.PredefinedSetsOfAdditionalDetailsAndInformation;
			
			If Not PredefinedSetsMatch(PredefinedSets, Saved, HasDeleted) Then
				Saved = Undefined;
			EndIf;
		EndIf;
		
		If Saved = Undefined Then
			HasChanges = True;
			StandardSubsystemsServer.SetApplicationPerformenceParameter(
				"AdditionalAttributesAndInformationParameters",
				"PredefinedSetsOfAdditionalDetailsAndInformation",
				PredefinedSets);
		EndIf;
		
		StandardSubsystemsServer.ConfirmUpdatingApplicationWorkParameter(
			"AdditionalAttributesAndInformationParameters",
			"PredefinedSetsOfAdditionalDetailsAndInformation");
		
		StandardSubsystemsServer.AddChangesToApplicationPerformenceParameters(
			"AdditionalAttributesAndInformationParameters",
			"PredefinedSetsOfAdditionalDetailsAndInformation",
			New FixedStructure("HasDeleted", HasDeleted));
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function PredefinedSets()
	
	PredefinedSets = New Map;
	
	NamesOfPredefined = Metadata.Catalogs.AdditionalAttributesAndInformationSets.GetPredefinedNames();
	
	For Each Name IN NamesOfPredefined Do
		PredefinedSets.Insert(
			Name, PropertiesManagementService.DescriptionPredefinedSet(Name));
	EndDo;
	
	Return New FixedMap(PredefinedSets);
	
EndFunction

Function PredefinedSetsMatch(NewSets, OldSets, HasDeleted)
	
	PredefinedSetsMatch =
		NewSets.Count() = OldSets.Count();
	
	For Each Set IN OldSets Do
		If NewSets.Get(Set.Key) = Undefined Then
			PredefinedSetsMatch = False;
			HasDeleted = True;
			Break;
		ElsIf Set.Value <> NewSets.Get(Set.Key) Then
			PredefinedSetsMatch = False;
		EndIf;
	EndDo;
	
	Return PredefinedSetsMatch;
	
EndFunction

#EndRegion

#EndIf
