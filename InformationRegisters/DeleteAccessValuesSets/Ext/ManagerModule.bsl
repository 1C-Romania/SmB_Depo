#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Handler of the infobase update.
Function MoveDataToNewTable() Export
	
	DataAvailabilityQuery = New Query;
	DataAvailabilityQuery.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.DeleteAccessValuesSets AS DeleteAccessValuesSets";
	
	If DataAvailabilityQuery.Execute().IsEmpty() Then
		Return True;
	EndIf;
	
	If Not AccessManagement.LimitAccessOnRecordsLevel() Then
		RecordSet = InformationRegisters.DeleteAccessValuesSets.CreateRecordSet();
		RecordSet.Write();
	EndIf;
	
	ObjectsTypes = AccessManagementServiceReUse.TypesOfObjectsInSubscriptionsToEvents(
		"RecordSetsOfAccessValues", True);
	
	Query = New Query;
	Query.Parameters.Insert("ObjectsTypes", ObjectsTypes);
	Query.Text =
	"SELECT DISTINCT TOP 10000
	|	DeleteAccessValuesSets.Object
	|FROM
	|	InformationRegister.DeleteAccessValuesSets AS DeleteAccessValuesSets
	|		INNER JOIN Catalog.MetadataObjectIDs AS IDs
	|		ON (VALUETYPE(DeleteAccessValuesSets.Object) = VALUETYPE(IDs.EmptyRefValue))
	|			AND (IDs.EmptyRefValue IN (&ObjectsTypes))";
	
	Selection = Query.Execute().Select();
	OldRecordSet = InformationRegisters.DeleteAccessValuesSets.CreateRecordSet();
	NewRecordSet = InformationRegisters.AccessValuesSets.CreateRecordSet();
	
	CheckQuery = New Query;
	CheckQuery.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessValuesSets AS AccessValuesSets
	|WHERE
	|	AccessValuesSets.Object = &Object";
	
	While Selection.Next() Do
		OldRecordSet.Filter.Object.Set(Selection.Object);
		NewRecordSet.Filter.Object.Set(Selection.Object);
		CheckQuery.SetParameter("Object", Selection.Object);
		NewRecordSet.Clear();
		NewSets = AccessManagement.TableAccessValueSets();
		
		ObjectMetadata = Selection.Object.Metadata();
		ObjectWithSets = ObjectMetadata.TabularSections.Find("AccessValuesSets") <> Undefined;
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.AccessValuesSets");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.SetValue("Object", Selection.Object);
		If ObjectWithSets Then
			LockItem = Block.Add(ObjectMetadata.FullName());
			LockItem.Mode = DataLockMode.Exclusive;
			LockItem.SetValue("Ref", Selection.Object);
		EndIf;
		
		BeginTransaction();
		Try
			Block.Lock();
			If CheckQuery.Execute().IsEmpty() Then
				OldRecordSet.Read();
				AdjustmentFilled = False;
				FillNewObjectSets(OldRecordSet, NewSets, AdjustmentFilled);
				If AdjustmentFilled AND ObjectWithSets Then
					Object = Selection.Object.GetObject();
					Object.AccessValuesSets.Load(NewSets);
					InfobaseUpdate.WriteData(Object);
				EndIf;
				AccessManagementService.PrepareAccessToRecordsValuesSets(
					Selection.Object, NewSets, True);
				NewRecordSet.Load(NewSets);
				NewRecordSet.Write();
			EndIf;
			OldRecordSet.Clear();
			OldRecordSet.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
	If Selection.Count() < 10000 Then
		
		If Not DataAvailabilityQuery.Execute().IsEmpty() Then
			RecordSet = InformationRegisters.DeleteAccessValuesSets.CreateRecordSet();
			RecordSet.Write();
		EndIf;
		
		WriteLogEvent(
			NStr("en = 'Acces management. Filling data for access restriction'",
				 CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en = 'The data transfer from the DeleteAccessValuesSets register is complete.'"),
			EventLogEntryTransactionMode.Transactional);
	Else
		WriteLogEvent(
			NStr("en = 'Acces management. Filling data for access restriction'",
				 CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Information,
			,
			,
			NStr("en = 'The step of the data transfer from the DeleteAccessValuesSets register is executed.'"),
			EventLogEntryTransactionMode.Transactional);
	EndIf;
	
	Return False;
	
EndFunction

Procedure FillNewObjectSets(OldRecords, NewSets, AdjustmentFilled)
	
	ValidSets = New Map;
	
	For Each OldRow IN OldRecords Do
		If OldRow.Read Or OldRow.Update Then
			ValidSets.Insert(OldRow.NumberOfSet, True);
		EndIf;
	EndDo;
	
	RightSettingsOwnerTypes = AccessManagementServiceReUse.Parameters(
		).PossibleRightsForObjectRightsSettings.ByRefsTypes;
	
	For Each OldRow IN OldRecords Do
		If ValidSets.Get(OldRow.NumberOfSet) = Undefined Then
			Continue;
		EndIf;
		NewRow = NewSets.Add();
		FillPropertyValues(NewRow, OldRow, "SetNumber, AccessValue, Reading, Change");
		
		If OldRow.AccessKind = ChartsOfCharacteristicTypes.DeleteAccessKinds.EmptyRef() Then
			If OldRow.AccessValue = Undefined Then
				NewRow.AccessValue = Enums.AdditionalAccessValues.AccessDenied;
			Else
				NewRow.AccessValue = Enums.AdditionalAccessValues.AccessPermitted;
			EndIf;
		
		ElsIf OldRow.AccessKind = ChartsOfCharacteristicTypes.DeleteAccessKinds.ReadRight
		      OR OldRow.AccessKind = ChartsOfCharacteristicTypes.DeleteAccessKinds.EditRight
		      OR OldRow.AccessKind = ChartsOfCharacteristicTypes.DeleteAccessKinds.AddRight Then
			
			If TypeOf(OldRow.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				If Metadata.FindByType(TypeOf(OldRow.AccessValue)) = Undefined Then
					NewRow.AccessValue = Catalogs.MetadataObjectIDs.EmptyRef();
				Else
					NewRow.AccessValue =
						CommonUse.MetadataObjectID(TypeOf(OldRow.AccessValue));
				EndIf;
			EndIf;
			
			If OldRow.AccessKind = ChartsOfCharacteristicTypes.DeleteAccessKinds.ReadRight Then
				NewRow.Adjustment = Catalogs.MetadataObjectIDs.EmptyRef();
			Else
				NewRow.Adjustment = NewRow.AccessValue;
			EndIf;
			
		ElsIf RightSettingsOwnerTypes.Get(TypeOf(OldRow.AccessValue)) <> Undefined Then
			
			NewRow.Adjustment = CommonUse.MetadataObjectID(TypeOf(OldRow.Object));
		EndIf;
		
		If ValueIsFilled(NewRow.Adjustment) Then
			AdjustmentFilled = True;
		EndIf;
	EndDo;
	
	AccessManagement.AddAccessValueSets(
		NewSets, AccessManagement.TableAccessValueSets(), False, True);
	
EndProcedure

#EndRegion

#EndIf