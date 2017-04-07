#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Interactive deletion of marked objects.

// Deletes marked objects, used when you delete interactively in the background job.
//
// Parameters:
//   ExecuteParameters - Structure - The parameters necessary for deletion.
//   StorageAddress - String - Temporary storage address.
//
Procedure DeletionMarkedObjectsInteractively(ExecuteParameters, StorageAddress) Export
	DeletionMarkedObjects(ExecuteParameters);
	PutToTempStorage(ExtractResult(ExecuteParameters), StorageAddress);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Deleting marked objects from scheduled job.

// Deletes marked objects from the scheduled job.
Procedure DeletionMarkedObjectsFromScheduledJob() Export
	
	ExecuteParameters = New Structure;
	DeletionMarkedObjects(ExecuteParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initialization and launch.

// Default mechanics of marked objects deletion.
Procedure DeletionMarkedObjects(ExecuteParameters)
	
	If Not Users.InfobaseUserWithFullAccess() Then
		Raise NStr("en='Insufficient rights to perform the operation.';ru='Недостаточно прав для выполнения операции.'");
	EndIf;
	
	InitializeParameters(ExecuteParameters);
	
	If ExecuteParameters.SearchMarked Then
		GetMarkedForDeletion(ExecuteParameters);
	EndIf;
	
	If Not ExecuteParameters.DeleteMarked Then
		Return;
	EndIf;
	
	If ExecuteParameters.Interactive
		AND ExecuteParameters.AllMarkedForDeletion.Count() = 0 Then
		Return; // Do not delete technological objects on interactive launch if there are no custom objects.
	EndIf;
	
	If ExecuteParameters.Exclusive Then
		DeletionMarkedObjectsExclusively(ExecuteParameters);
	Else // Not exclusive.
		DeletionMarkedObjectsCompetitively(ExecuteParameters);
	EndIf;
	
	Handlers = CommonUse.ServiceEventProcessor("StandardSubsystems.MarkedObjectDeletion\AfterDeletingMarked");
	For Each Handler IN Handlers Do
		Handler.Module.AfterDeletingMarked(ExecuteParameters);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Competitive deletion of marked objects.

// Default mechanics.
Procedure DeletionMarkedObjectsCompetitively(ExecuteParameters)
	SetPrivilegedMode(True);
	
	// Deletion of technological objects (which were created and marked for deletion without the participation of the user).
	If ExecuteParameters.TechnologicalObjects <> Undefined Then
		ClientMarkBypassStart(ExecuteParameters, "TechnologicalObjects");
		For Each Ref IN ExecuteParameters.TechnologicalObjects Do
			DeleteReference(ExecuteParameters, Ref); // For technological objects the result is not displayed.
			ClientMarkCollectionBypassProgress(ExecuteParameters, "TechnologicalObjects");
		EndDo;
	EndIf;
	
	// Deleting the objects marked for deletion.
	ClientMarkBypassStart(ExecuteParameters, "CustomObjects");
	For Each Ref IN ExecuteParameters.CustomObjects Do
		Result = DeleteReference(ExecuteParameters, Ref);
		RegisterDeletionResult(ExecuteParameters, Ref, Result, "CustomObjects");
		ClientMarkCollectionBypassProgress(ExecuteParameters, "CustomObjects");
	EndDo;
	
	// Deleting the chains (linearly linked objects).
	ClientMarkBypassStart(ExecuteParameters, "RepeatedlyDeleted");
	While ExecuteParameters.RepeatedlyDeleted.Count() > 0 Do
		Ref = ExecuteParameters.RepeatedlyDeleted[0];
		ExecuteParameters.RepeatedlyDeleted.Delete(0);
		
		Result = DeleteReference(ExecuteParameters, Ref);
		
		RegisterDeletionResult(ExecuteParameters, Ref, Result, "RepeatedlyDeleted");
		ClientMarkCollectionBypassProgress(ExecuteParameters, "RepeatedlyDeleted");
	EndDo;
	
	// Deleting the cycles (circular links of objects).
	DeleteRemainingObjectsInOneTransaction(ExecuteParameters);
	
EndProcedure

// Deleting a single object with control of the result and transaction rollback in case of failure.
Function DeleteReference(ExecuteParameters, Ref)
	Result = New Structure;
	Result.Insert("Success", Undefined);
	Result.Insert("ErrorInfo", Undefined);
	Result.Insert("ImpedingRemoval", Undefined);
	Result.Insert("NestedAndSubordinateObjects", New Array);
	Result.Insert("Quantity", 0);
	
	Information = GenerateTypeInformation(ExecuteParameters, TypeOf(Ref));
	
	BeginTransaction();
	Try
		TryToDeleteReference(ExecuteParameters, Ref, Information, Result);
	Except
		Result.Success = False;
		Result.ErrorInfo = ErrorInfo();
	EndTry;
	If Result.Success Then
		CommitTransaction();
	Else
		RollbackTransaction();
		WriteWarning(Ref, Result.ErrorInfo);
	EndIf;
	
	If TypeOf(Result.ImpedingRemoval) = Type("ValueTable") Then
		Result.ImpedingRemoval.Columns[0].Name = "RemovedRefs";
		Result.ImpedingRemoval.Columns[1].Name = "FoundReference";
		Result.ImpedingRemoval.Columns[2].Name = "FindMetadata";
		For Each FoundReference IN Result.NestedAndSubordinateObjects Do
			TableRow = Result.ImpedingRemoval.Add();
			TableRow.RemovedRefs        = Ref;
			TableRow.FoundReference     = FoundReference;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Mechanics of object deletion and references search.
Procedure TryToDeleteReference(ExecuteParameters, Ref, Information, Result)
	Block = New DataLock;
	LockItem = Block.Add(Information.FullName);
	LockItem.SetValue("Ref", Ref);
	Block.Lock();
	
	Object = Ref.GetObject();
	If Object = Undefined Then
		Result.Success = True; // The object was already deleted.
		Return;
	EndIf;
	If Object.DeletionMark <> True Then
		Result.Success = False;
		Result.ErrorInfo = NStr("en='The object is not marked for deletion.';ru='Объект не помечен на удаление.'");
		Return;
	EndIf;
	
	FindNestedAndSubordinateObjects(ExecuteParameters, Ref, Information, Result);
	
	Object.Delete();
	
	FindImpedingRemoval(ExecuteParameters, Ref, Information, Result);
	
	If Result.Quantity = 0 Then
		Result.Success = True;
	Else
		Result.Success = False;
		Result.ErrorInfo = NStr("en='The object is used in other application objects.';ru='Объект используется в других объектах программы.'");
	EndIf;
EndProcedure

// Search for nested and subordinate references (hierarchy and link by the owner). Completed before deletion.
Procedure FindNestedAndSubordinateObjects(ExecuteParameters, Ref, Information, Result)
	
	If Information.Hierarchical Then
		Query = New Query(Information.QueryTextByHierarchy);
		Query.SetParameter("RemovedRefs", Ref);
		NestedObjects = Query.Execute().Unload();
		For Each TableRow IN NestedObjects Do
			Result.NestedAndSubordinateObjects.Add(TableRow.Ref);
		EndDo;
		Result.Quantity = Result.Quantity + NestedObjects.Count();
	EndIf;
	
	If Information.AreSubordinates Then
		Query = New Query(Information.QueryTextBySubordinate);
		Query.SetParameter("RemovedRefs", Ref);
		SubordinateObjects = Query.Execute().Unload();
		For Each TableRow IN SubordinateObjects Do
			Result.NestedAndSubordinateObjects.Add(TableRow.Ref);
		EndDo;
		Result.Quantity = Result.Quantity + SubordinateObjects.Count();
	EndIf;
	
EndProcedure

// Searching the references by scanning all the tables. Executed after deletion.
Procedure FindImpedingRemoval(ExecuteParameters, Ref, Information, Result)
	
	SearchRefs = New Array;
	SearchRefs.Add(Ref);
	
	ImpedingRemoval = FindByRef(SearchRefs);
	
	// Skipping the references from sequence limits.
	Quantity = ImpedingRemoval.Count();
	ColumnName = ImpedingRemoval.Columns[1].Name;
	For Number = 1 To Quantity Do
		ReverseIndex = Quantity - Number;
		TableRow = ImpedingRemoval[ReverseIndex];
		PreventingRef = TableRow[ColumnName];
		If PreventingRef = Ref
			Or DocumentAlreadyRemoved(ExecuteParameters, PreventingRef) Then
			ImpedingRemoval.Delete(TableRow);
		EndIf;
	EndDo;
	
	// Result registration.
	Result.ImpedingRemoval = ImpedingRemoval;
	Result.Quantity = Result.Quantity + Result.ImpedingRemoval.Count();
	
EndProcedure

// Search the document reference in the data base.
Function DocumentAlreadyRemoved(ExecuteParameters, Ref)
	If Ref = Undefined Then
		Return False; // Not a document.
	EndIf;
	Information = GenerateTypeInformation(ExecuteParameters, TypeOf(Ref));
	If Information.Type <> "DOCUMENT" Then
		Return False; // Not a document.
	EndIf;
	Query = New Query("SELECT TOP 1 1 FROM "+ Information.FullName +" Where Ref = &Ref");
	Query.SetParameter("Ref", Ref);
	Return Query.Execute().IsEmpty();
EndFunction

// Deleting the cycles (circular links of objects).
Procedure DeleteRemainingObjectsInOneTransaction(ExecuteParameters)
	Var Ref;
	
	// 1. The objects that can not be deleted.
	//    Result from definition of unresolved links.
	ObjectsImpossibleToDelete = New Array;
	NestedIrresolvableLinks = New Array;
	
	// 1.1. Primary criteria to determine
	//      irresolvable links is that an object preventing deletion is not marked for deletion.
	For Each TableRow IN ExecuteParameters.ImpedingRemoval Do
		If ExecuteParameters.NotRemoved.Find(TableRow.FoundReference) = Undefined
			AND ObjectsImpossibleToDelete.Find(TableRow.RemovedRefs) = Undefined Then
			ObjectsImpossibleToDelete.Add(TableRow.RemovedRefs);
			Found = ExecuteParameters.ImpedingRemoval.FindRows(New Structure("FoundReference", TableRow.RemovedRefs));
			NestedIrresolvableLinks.Add(Found);
		EndIf;
	EndDo;
	
	// 1.2. Next with the
	//      help of array NestedIrresolvableLinks irresolvable subordinates come out - "links of links", "links of links of links", etc...
	IndexOf = 0;
	While IndexOf < NestedIrresolvableLinks.Count() Do
		Found = NestedIrresolvableLinks[IndexOf];
		IndexOf = IndexOf + 1;
		For Each TableRow IN Found Do
			If ObjectsImpossibleToDelete.Find(TableRow.RemovedRefs) = Undefined Then
				ObjectsImpossibleToDelete.Add(TableRow.RemovedRefs);
				Found = ExecuteParameters.ImpedingRemoval.FindRows(New Structure("FoundReference", TableRow.RemovedRefs));
				NestedIrresolvableLinks.Add(Found);
			EndIf;
		EndDo;
	EndDo;
	
	// 2. Objects that you can try to delete in one transaction.
	//    = Array of deleted - An array of objects that are impossible to delete.
	RefArray = New Array;
	For Each Ref IN ExecuteParameters.NotRemoved Do
		If ObjectsImpossibleToDelete.Find(Ref) = Undefined Then
			RefArray.Add(Ref);
		EndIf;
	EndDo;
	
	Quantity = RefArray.Count();
	If Quantity = 0 Then
		Return; // No objects for deletion.
	EndIf;
	
	// 3. Including all the objects into one transaction and trying to delete.
	Success = False;
	BeginTransaction();
	Try
		For Number = 1 To Quantity Do
			ReverseIndex = Quantity - Number;
			Ref = RefArray[ReverseIndex];
			
			Information = GenerateTypeInformation(ExecuteParameters, TypeOf(Ref));
			
			Block = New DataLock;
			LockItem = Block.Add(Information.FullName);
			LockItem.SetValue("Ref", Ref);
			Block.Lock();
			
			Object = Ref.GetObject();
			If Object = Undefined Then // The object was already deleted.
				Continue;
			EndIf;
			If Object.DeletionMark <> True Then
				RefArray.Delete(ReverseIndex); // The object is already not marked for deletion.
				Continue;
			EndIf;
			
			Object.Delete();
		EndDo;
		Ref = Undefined;
		
		If RefArray.Count() > 0 Then
			ImpedingRemoval = FindByRef(RefArray);
			
			ColumnName = ImpedingRemoval.Columns[1].Name;
			For Each Ref IN RefArray Do
				SearchForNotImpeding = New Structure(ColumnName, Ref);
				NotImpeding = ImpedingRemoval.FindRows(SearchForNotImpeding);
				For Each TableRow IN NotImpeding Do
					ImpedingRemoval.Delete(TableRow);
				EndDo;
			EndDo;
			
			If ImpedingRemoval.Count() = 0 Then
				Success = True;
			EndIf;
		EndIf;
		
	Except
		WriteWarning(Ref, ErrorInfo());
	EndTry;
	
	// 4. Result registration (if successful).
	If Success Then
		CommitTransaction();
		
		For Each Ref IN RefArray Do
			// Registering the reference in the collection of deleted objects.
			If ExecuteParameters.Deleted.Find(Ref) = Undefined Then
				ExecuteParameters.Deleted.Add(Ref);
			EndIf;
			
			// Deleting the reference from the collection are not deleted objects.
			IndexOf = ExecuteParameters.NotRemoved.Find(Ref);
			If IndexOf <> Undefined Then
				ExecuteParameters.NotRemoved.Delete(IndexOf);
			EndIf;
			
			// Clearing the information about the links from remote objects.
			Found = ExecuteParameters.ImpedingRemoval.FindRows(New Structure("RemovedRefs", Ref));
			For Each TableRow IN Found Do
				ExecuteParameters.ImpedingRemoval.Delete(TableRow);
			EndDo;
			
			// Clearing the information about the connections with remote objects.
			Found = ExecuteParameters.ImpedingRemoval.FindRows(New Structure("FoundReference", Ref));
			For Each TableRow IN Found Do
				ExecuteParameters.ImpedingRemoval.Delete(TableRow);
			EndDo;
		EndDo;
	Else
		RollbackTransaction();
	EndIf;
EndProcedure

// Registering the result of deletion and filling in collection DeletedAgain.
Procedure RegisterDeletionResult(ExecuteParameters, Ref, Result, CollectionName)
	If Result.Success Then
		// Registering the reference in the collection of deleted objects.
		ExecuteParameters.Deleted.Add(Ref);
		
		// Exception of remote object from the reasons for not deleting other objects. Search.
		IrrelevantReasons = ExecuteParameters.ImpedingRemoval.FindRows(New Structure("FoundReference", Ref));
		For Each Cause IN IrrelevantReasons Do
			// Deleting the reasons for not deleting another object.
			RemovedRefs = Cause.RemovedRefs;
			ExecuteParameters.ImpedingRemoval.Delete(Cause);
			// Searching other reasons for not deleting another object.
			If ExecuteParameters.ImpedingRemoval.Find(RemovedRefs, "RemovedRefs") = Undefined Then
				// All the causes for not deleting another object are eliminated.
				// Registration of another object for repeated deletion.
				ExecuteParameters.RepeatedlyDeleted.Add(RemovedRefs);
				If CollectionName = "RepeatedlyDeleted" AND ExecuteParameters.Interactive Then
					ExecuteParameters.Total = ExecuteParameters.Total + 1;
				EndIf;
				// Clearing the record of another object from collection "Undeleted".
				IndexOf = ExecuteParameters.NotRemoved.Find(RemovedRefs);
				If IndexOf <> Undefined Then
					ExecuteParameters.NotRemoved.Delete(IndexOf);
				EndIf;
			EndIf;
		EndDo;
		
	Else // Unsuccessful.
		
		ExecuteParameters.NotRemoved.Add(Ref);
		
		If TypeOf(Result.ErrorInfo) = Type("ErrorInfo")
			Or Result.ImpedingRemoval = Undefined Then // Error text
			If TypeOf(Result.ErrorInfo) = Type("ErrorInfo") Then
				ErrorText = BriefErrorDescription(Result.ErrorInfo);
			Else
				ErrorText = Result.ErrorInfo;
			EndIf;
			Cause = ExecuteParameters.ImpedingRemoval.Add();
			Cause.RemovedRefs    = Ref;
			Cause.DeletedType       = TypeOf(Cause.RemovedRefs);
			Cause.FoundReference = ErrorText;
			Cause.DetectedType    = Type("String");
			GenerateTypeInformation(ExecuteParameters, Cause.DeletedType);
		Else // Registration of the links (reasons for not deleting) to display to the user.
			For Each TableRow IN Result.ImpedingRemoval Do
				WriteReasonIntoResult(ExecuteParameters, TableRow);
			EndDo;
		EndIf;
		
	EndIf; // Result.Success.
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exclusive deletion of marked objects.

// Default mechanics of marked objects deletion.
Procedure DeletionMarkedObjectsExclusively(ExecuteParameters)
	
	If Not ExecuteParameters.Property("RefsSearchExceptions") Then
		ExecuteParameters.Insert("RefsSearchExceptions", CommonUse.GetOverallRefSearchExceptionList());
	EndIf;
	If Not ExecuteParameters.Property("ExcludingRules") Then
		ExecuteParameters.Insert("ExcludingRules", New Map); // Cache of search exception rules.
	EndIf;
	
	ObjectsToDelete = ExecuteParameters.AllMarkedForDeletion;
	
	While ObjectsToDelete.Count() > 0 Do
		
		ClientMarkBypassStart(ExecuteParameters, "ExclusiveDeletion");
		
		ImpedingRemoval = New ValueTable;
		
		// Trying to delete while controlling referential integrity.
		Try
			SetPrivilegedMode(True);
			DeleteObjects(ObjectsToDelete, True, ImpedingRemoval);
			SetPrivilegedMode(False);
		Except
			WriteWarning(Undefined, ErrorInfo());
		EndTry;
		
		// Purpose of column names for the table of conflicts generated on deletion.
		ImpedingRemoval.Columns[0].Name = "RemovedRefs";
		ImpedingRemoval.Columns[1].Name = "FoundReference";
		ImpedingRemoval.Columns[2].Name = "FindMetadata";
		
		AllLinksInExceptions = True;
		
		// Analysis of the reasons not to delete (places of usage of the objects marked for deletion).
		ClientMarkBypassStart(ExecuteParameters, "ImpedingRemoval", ImpedingRemoval);
		For Each TableRow IN ImpedingRemoval Do
			ClientMarkCollectionBypassProgress(ExecuteParameters, "ImpedingRemoval");
			
			// Check of the exclusion rules.
			If LinkInLinkSearchExceptions(ExecuteParameters, TableRow) Then
				Continue; // The link does not prevent the removal.
			EndIf;
			
			// Cannot delete the object (found reference or register record interferes with it).
			AllLinksInExceptions = False;
			
			// Abbreviation of deleted objects.
			IndexOf = ObjectsToDelete.Find(TableRow.RemovedRefs);
			If IndexOf <> Undefined Then
				ObjectsToDelete.Delete(IndexOf);
			EndIf;
			
			// Registration of the link to display to the user.
			WriteReasonIntoResult(ExecuteParameters, TableRow);
		EndDo;
		
		// Delete without verification if there are all the links in the exceptions of reference search.
		If AllLinksInExceptions Then
			Try
				SetPrivilegedMode(True);
				DeleteObjects(ObjectsToDelete, False);
				SetPrivilegedMode(False);
			Except
				WriteWarning(Undefined, ErrorInfo());
			EndTry;
			Break; // Exit from the cycle.
		EndIf;
	EndDo;
	
	ExecuteParameters.Insert("Deleted", ObjectsToDelete);
	ExecuteParameters.Delete("RefsSearchExceptions");
	ExecuteParameters.Delete("ExcludingRules");
	
EndProcedure

// Checks that there is a link in the exceptions.
Function LinkInLinkSearchExceptions(ExecuteParameters, TableRow)
	// Definition of excluding rule for metadata object preventing the deletion:
	// For the registers (so called "non-object tables″) - array of attributes for search in the records of the register.
	// For reference types (so-called "object tables") - ready query for search in the attributes.
	Rule = ExecuteParameters.ExcludingRules[TableRow.FindMetadata]; // Cache.
	If Rule = Undefined Then
		Rule = GenerateExcludingRule(ExecuteParameters, TableRow);
		ExecuteParameters.ExcludingRules.Insert(TableRow.FindMetadata, Rule);
	EndIf;
	
	// Checking the excluding rule.
	If Rule = "*" Then
		Return True; // Can be deleted (found metadata object does not interfere).
	ElsIf TypeOf(Rule) = Type("Array") Then // Names of register dimensions.
		For Each AttributeName IN Rule Do
			If TableRow.FoundReference[AttributeName] = TableRow.RemovedRefs Then
				Return True; // Can be deleted (found record of the register does not interfere).
			EndIf;
		EndDo;
	ElsIf TypeOf(Rule) = Type("Query") Then // Query to a reference object.
		Rule.SetParameter("RemovedRefs", TableRow.RemovedRefs);
		Rule.SetParameter("FoundReference", TableRow.FoundReference);
		If Not Rule.Execute().IsEmpty() Then
			Return True; // You can delete it (found reference does not prevent it).
		EndIf;
	EndIf;
	
	Return False;
EndFunction

// Links the rule in the optimal way for the check.
Function GenerateExcludingRule(ExecuteParameters, TableRow)
	ExceptSearch = ExecuteParameters.RefsSearchExceptions[TableRow.FindMetadata];
	If ExceptSearch = "*" Then
		Return "*"; // Can be deleted (found metadata object does not interfere).
	EndIf;
	
	// Generating an excluding rule.
	ThisIsInformationRegister = Metadata.InformationRegisters.Contains(TableRow.FindMetadata);
	If ThisIsInformationRegister
		Or Metadata.AccountingRegisters.Contains(TableRow.FindMetadata) // ThisIsAccountingRegister
		Or Metadata.AccumulationRegisters.Contains(TableRow.FindMetadata) Then // ThisIsAccumulationRegister
		
		Rule = New Array;
		If ThisIsInformationRegister Then
			For Each Dimension IN TableRow.FindMetadata.Dimensions Do
				If Dimension.Master Then
					Rule.Add(Dimension.Name);
				EndIf;
			EndDo;
		Else
			For Each Dimension IN TableRow.FindMetadata.Dimensions Do
				Rule.Add(Dimension.Name);
			EndDo;
		EndIf;
		
		If TypeOf(ExceptSearch) = Type("Array") Then
			For Each AttributeName IN ExceptSearch Do
				If Rule.Find(AttributeName) = Undefined Then
					Rule.Add(AttributeName);
				EndIf;
			EndDo;
		EndIf;
		
	ElsIf TypeOf(ExceptSearch) = Type("Array") Then
		
		TextsOfRequests = New Map;
		NameRootTable = TableRow.FindMetadata.FullName();
		
		For Each PathToAttribute IN ExceptSearch Do
			DotPosition = Find(PathToAttribute, ".");
			If DotPosition = 0 Then
				FullTableName = NameRootTable;
				AttributeName = PathToAttribute;
			Else
				FullTableName = NameRootTable + "." + Left(PathToAttribute, DotPosition - 1);
				AttributeName = Mid(PathToAttribute, DotPosition + 1);
			EndIf;
			
			NestedSelectText = TextsOfRequests.Get(FullTableName);
			If NestedSelectText = Undefined Then
				NestedSelectText = 
				"SELECT TOP 1
				|	1
				|FROM
				|	"+ FullTableName +" AS
				|Table
				|WHERE Table.Ref
				|	= &FoundRef AND (";
			Else
				NestedSelectText = NestedSelectText + Chars.LF + Chars.Tab + Chars.Tab + "OR ";
			EndIf;
			NestedSelectText = NestedSelectText + "Table." + AttributeName + " = &RemovedReference";
			
			TextsOfRequests.Insert(FullTableName, NestedSelectText);
		EndDo;
		
		QueryText = "";
		For Each KeyAndValue IN TextsOfRequests Do
			If QueryText <> "" Then
				QueryText = QueryText + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF;
			EndIf;
			QueryText = QueryText + KeyAndValue.Value + ")";
		EndDo;
		
		Rule = New Query;
		Rule.Text = QueryText;
		
	Else
		
		Rule = "";
		
	EndIf;
	
	Return Rule;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Common mechanics.

// Initializes the structure of parameters required to perform other service methods.
Procedure InitializeParameters(ExecuteParameters) Export
	// Definition of the parameters for application operation.
	If Not ExecuteParameters.Property("SearchMarked") Then
		ExecuteParameters.Insert("SearchMarked", True);
	EndIf;
	If Not ExecuteParameters.Property("DeleteMarked") Then
		ExecuteParameters.Insert("DeleteMarked", True);
	EndIf;
	If Not ExecuteParameters.Property("Exclusive") Then
		ExecuteParameters.Insert("Exclusive", False);
	EndIf;
	If Not ExecuteParameters.Property("TechnologicalObjects") Then
		ExecuteParameters.Insert("TechnologicalObjects", New Array);
	EndIf;
	If Not ExecuteParameters.Property("CustomObjects") Then
		ExecuteParameters.Insert("CustomObjects", New Array);
	EndIf;
	If Not ExecuteParameters.Property("AllMarkedForDeletion") Then
		ExecuteParameters.Insert("AllMarkedForDeletion", New Array);
		CommonUseClientServer.SupplementArray(ExecuteParameters.AllMarkedForDeletion, ExecuteParameters.TechnologicalObjects);
		CommonUseClientServer.SupplementArray(ExecuteParameters.AllMarkedForDeletion, ExecuteParameters.CustomObjects);
	EndIf;
	If Not ExecuteParameters.Property("SaaS") Then
		ExecuteParameters.Insert("SaaS", CommonUseReUse.DataSeparationEnabled());
		If ExecuteParameters.SaaS Then
			ExecuteParameters.Insert("InDataArea", CommonUse.UseSessionSeparator());
			ExecuteParameters.Insert("MainDataSeparator",        CommonUseReUse.MainDataSeparator());
			ExecuteParameters.Insert("SupportDataSplitter", CommonUseReUse.SupportDataSplitter());
		EndIf;
	EndIf;
	If Not ExecuteParameters.Property("TypeInformation") Then
		ExecuteParameters.Insert("TypeInformation", New Map);
	EndIf;
	
	ImpedingRemoval = New ValueTable;
	ImpedingRemoval.Columns.Add("RemovedRefs");
	ImpedingRemoval.Columns.Add("DeletedType", New TypeDescription("Type"));
	ImpedingRemoval.Columns.Add("FoundReference");
	ImpedingRemoval.Columns.Add("DetectedType", New TypeDescription("Type"));
	ImpedingRemoval.Columns.Add("DetectedDeletionMark", New TypeDescription("Boolean"));
	
	ExecuteParameters.Insert("Deleted",              New Array);
	ExecuteParameters.Insert("NotRemoved",            New Array);
	ExecuteParameters.Insert("ImpedingRemoval", ImpedingRemoval);
	ExecuteParameters.Insert("RepeatedlyDeleted",      New Array);
	ExecuteParameters.Insert("Interactive",          ExecuteParameters.Property("RecordPeriod"));
	
	ClientInitializeParameters(ExecuteParameters);
EndProcedure

// Generates the array of the objects marked for deletion with the account of the separation.
Procedure GetMarkedForDeletion(ExecuteParameters) Export
	
	ClientMarkBypassStart(ExecuteParameters, "BeforeSearchingMarkedToDelete");
	MarkedObjectDeletionOverridable.BeforeSearchingMarkedToDelete(ExecuteParameters);
	
	SetPrivilegedMode(True);
	
	// Getting the list of objects marked for deletion.
	ClientMarkBypassStart(ExecuteParameters, "SearchMarkedForDeletion");
	ExecuteParameters.AllMarkedForDeletion = FindMarkedForDeletion();
	
	// Distribution of the objects marked for deletion by collection.
	ClientMarkBypassStart(ExecuteParameters, "AllMarkedForDeletion");
	Quantity = ExecuteParameters.AllMarkedForDeletion.Count();
	For Number = 1 To Quantity Do
		ReverseIndex = Quantity - Number;
		Ref = ExecuteParameters.AllMarkedForDeletion[ReverseIndex];
		
		Information = GenerateTypeInformation(ExecuteParameters, TypeOf(Ref));
		ClientMarkCollectionBypassProgress(ExecuteParameters, "AllMarkedForDeletion");
		
		If ExecuteParameters.SaaS
			AND ExecuteParameters.InDataArea
			AND Not Information.Divided Then
			ExecuteParameters.AllMarkedForDeletion.Delete(ReverseIndex);
			Continue; // Undivided objects can not be changed from a data area.
		EndIf;
		
		If Information.ThereArePredetermined AND Information.Predetermined.Find(Ref) <> Undefined Then
			ExecuteParameters.AllMarkedForDeletion.Delete(ReverseIndex);
			Continue; // Predefined items are created and deleted only automatically.
		EndIf;
		
		If Information.Technical = True Then
			ExecuteParameters.TechnologicalObjects.Add(Ref);
		Else
			ExecuteParameters.CustomObjects.Add(Ref);
		EndIf;
	EndDo;
EndProcedure

// Generates the information about the type of metadata object, such as full name, presentations, kind, etc.
Function GenerateTypeInformation(ExecuteParameters, Type) Export
	Information = ExecuteParameters.TypeInformation.Get(Type); // Cache.
	If Information <> Undefined Then
		Return Information;
	EndIf;
	
	Information = New Structure("FullName, ItemPresentation,
	|ListPresentation, Type, Reference,
	|Technical, Divided,
	|Hierarchical, QueryTextByHierarchy,
	|AreSubordinates, QueryTextBySubordinate, ThereArePredetermined, Predetermined");
	
	// Search for metadata object.
	MetadataObject = Metadata.FindByType(Type);
	
	// Filling in basic information.
	Information.FullName = Upper(MetadataObject.FullName());
	
	// Presentations: of the item and the list.
	StandardProperties = New Structure("ObjectPresentation, ExtendedObjectPresentation, ListPresentation, ExtendedListPresentation");
	FillPropertyValues(StandardProperties, MetadataObject);
	If ValueIsFilled(StandardProperties.ObjectPresentation) Then
		Information.ItemPresentation = StandardProperties.ObjectPresentation;
	ElsIf ValueIsFilled(StandardProperties.ExtendedObjectPresentation) Then
		Information.ItemPresentation = StandardProperties.ExtendedObjectPresentation;
	Else
		Information.ItemPresentation = MetadataObject.Presentation();
	EndIf;
	If ValueIsFilled(StandardProperties.ListPresentation) Then
		Information.ListPresentation = StandardProperties.ListPresentation;
	ElsIf ValueIsFilled(StandardProperties.ExtendedListPresentation) Then
		Information.ListPresentation = StandardProperties.ExtendedListPresentation;
	Else
		Information.ListPresentation = MetadataObject.Presentation();
	EndIf;
	
	// Kind and its properties.
	Information.Type = Left(Information.FullName, Find(Information.FullName, ".")-1);
	If Information.Type = "CATALOG"
		Or Information.Type = "DOCUMENT"
		Or Information.Type = "ENUM"
		Or Information.Type = "CHARTOFCHARACTERISTICTYPES"
		Or Information.Type = "CHARTOFACCOUNTS"
		Or Information.Type = "CHARTOFCALCULATIONTYPES"
		Or Information.Type = "BUSINESSPROCESS"
		Or Information.Type = "TASK"
		Or Information.Type = "EXCHANGEPLAN" Then
		Information.Reference = True;
	Else
		Information.Reference = False;
	EndIf;
	
	If Information.Type = "CATALOG"
		Or Information.Type = "CHARTOFCHARACTERISTICTYPES" Then
		Information.Hierarchical = MetadataObject.Hierarchical;
	ElsIf Information.Type = "CHARTOFACCOUNTS" Then
		Information.Hierarchical = True;
	Else
		Information.Hierarchical = False;
	EndIf;
	If Information.Hierarchical Then
		QueryPattern = "SELECT Ref FROM &FullName WHERE Parent = &RemovedRefs";
		Information.QueryTextByHierarchy = StrReplace(QueryPattern, "&FullName", Information.FullName);
	EndIf;
	
	Information.AreSubordinates = False;
	Information.QueryTextBySubordinate = "";
	If Information.Type = "CATALOG"
		Or Information.Type = "CHARTOFCHARACTERISTICTYPES"
		Or Information.Type = "EXCHANGEPLAN"
		Or Information.Type = "CHARTOFACCOUNTS"
		Or Information.Type = "CHARTOFCALCULATIONTYPES" Then
		
		QueryPattern = "SELECT Ref FROM Catalog.&Name WHERE Owner = &RemovedRefs";
		QueryText = "";
		
		For Each Catalog IN Metadata.Catalogs Do
			If Catalog.Owners.Contains(MetadataObject) Then
				If Information.AreSubordinates = False Then
					Information.AreSubordinates = True;
				Else
					QueryText = QueryText + Chars.LF + "UNION ALL" + Chars.LF;
				EndIf;
				QueryText = QueryText + StrReplace(QueryPattern, "&Name", Catalog.Name);
			EndIf;
		EndDo;
		
		Information.QueryTextBySubordinate = QueryText;
	EndIf;
	
	If Information.FullName = "CATALOG.METADATAOBJECTSIDENTIFIERS"
		Or Information.FullName = "CATALOG.PREDEFINEDREPORTSVARIANTS" Then
		Information.Technical = True;
		Information.Divided = False;
	Else
		Information.Technical = False;
		If ExecuteParameters.SaaS Then
			Information.Divided = CommonUse.IsSeparatedMetadataObject(MetadataObject, ExecuteParameters.MainDataSeparator)
				Or CommonUse.IsSeparatedMetadataObject(MetadataObject, ExecuteParameters.SupportDataSplitter);
		EndIf;
	EndIf;
	
	If Information.Type = "CATALOG"
		Or Information.Type = "CHARTOFCHARACTERISTICTYPES"
		Or Information.Type = "CHARTOFACCOUNTS"
		Or Information.Type = "CHARTOFCALCULATIONTYPES" Then
		Query = New Query("SELECT Ref FROM "+ Information.FullName +" WHERE Predefined And DeletionMark");
		Information.Predetermined = Query.Execute().Unload().UnloadColumn("Ref");
		Information.ThereArePredetermined = Information.Predetermined.Count() > 0;
	Else
		Information.ThereArePredetermined = False;
	EndIf;
	
	ExecuteParameters.TypeInformation.Insert(Type, Information);
	
	Return Information;
EndFunction

// Registers warning in the events log monitor.
Procedure WriteWarning(Ref, ErrorInfo)
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		TextForLog = DetailErrorDescription(ErrorInfo);
	Else
		TextForLog = ErrorInfo;
	EndIf;
	
	WriteLogEvent(
		NStr("en='Delete marked';ru='Удаление помеченных'", CommonUseClientServer.MainLanguageCode()),
		EventLogLevel.Warning,
		,
		Ref,
		TextForLog);
EndProcedure

// Registration of the causes for not deleting.
Procedure WriteReasonIntoResult(ExecuteParameters, TableRow)
	DeletedType        = TypeOf(TableRow.RemovedRefs);
	DeletedInformation = GenerateTypeInformation(ExecuteParameters, DeletedType);
	If DeletedInformation.Technical Then
		Return;
	EndIf;
	
	// Adding not deleted objects.
	If ExecuteParameters.NotRemoved.Find(TableRow.RemovedRefs) = Undefined Then
		ExecuteParameters.NotRemoved.Add(TableRow.RemovedRefs);
	EndIf;
	
	Cause = ExecuteParameters.ImpedingRemoval.Add();
	FillPropertyValues(Cause, TableRow);
	Cause.DeletedType    = DeletedType;
	Cause.DetectedType = TypeOf(Cause.FoundReference);
	
	If TableRow.FoundReference = Undefined Then
		If Metadata.Constants.Contains(TableRow.FindMetadata) Then
			Cause.DetectedType = Type("ConstantValueManager." + TableRow.FindMetadata.Name);
		Else
			Cause.FoundReference = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Unresolved references are found (%1)';ru='Обнаружены неразрешимые ссылки (%1)'"),
				TableRow.FindMetadata.Presentation());
			Cause.DetectedType = Type("String");
			Return;
		EndIf;
	EndIf;
	
	// Registration of the information about metadata objects (if required).
	DetectedInformation = GenerateTypeInformation(ExecuteParameters, Cause.DetectedType);
	
	// Filling subordinate fields.
	If DetectedInformation.Reference Then
		Cause.DetectedDeletionMark = CommonUse.ObjectAttributeValue(Cause.FoundReference, "DeletionMark");
	Else
		Cause.DetectedDeletionMark = False;
	EndIf;
EndProcedure

// Default mechanics of marked objects deletion.
Function ExtractResult(ExecuteParameters)
	DeletionResult = ExecuteParameters;
	DeletionResult.Delete("AllMarkedForDeletion");
	DeletionResult.Delete("AllMarkedForDeletion");
	Return DeletionResult;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Transferring the information to the client.

// Initializes the structure of parameters required for transfer to the client.
Procedure ClientInitializeParameters(ExecuteParameters)
	If Not ExecuteParameters.Interactive Then
		Return;
	EndIf;
	
	ExecuteParameters.Insert("AchievedPercent", 0);
	ExecuteParameters.Insert("Range", 0);
	ExecuteParameters.Insert("Total", 0);
	ExecuteParameters.Insert("Number", 0);
	ExecuteParameters.Insert("Time", CurrentSessionDate() - 0.1);
	
	ExecuteParameters.Insert("Ranges", New Map);
	
	TotalWeight = 0;
	If ExecuteParameters.SearchMarked Then
		ExecuteParameters.Ranges.Insert("BeforeSearchingMarkedToDelete", 5);
		ExecuteParameters.Ranges.Insert("SearchMarkedForDeletion", 4);
		ExecuteParameters.Ranges.Insert("AllMarkedForDeletion", 1);
		TotalWeight = TotalWeight + 10;
	EndIf;
	If ExecuteParameters.DeleteMarked Then
		If ExecuteParameters.Exclusive Then
			ExecuteParameters.Ranges.Insert("ExclusiveDeletion", 80);
			ExecuteParameters.Ranges.Insert("ImpedingRemoval", 10);
		Else // Not exclusive.
			ExecuteParameters.Ranges.Insert("TechnologicalObjects", 10);
			ExecuteParameters.Ranges.Insert("CustomObjects", 70);
			ExecuteParameters.Ranges.Insert("RepeatedlyDeleted", 10);
		EndIf;
		TotalWeight = TotalWeight + 90;
	EndIf;
	If TotalWeight <> 0 AND TotalWeight <> 100 Then
		Factor = 100/TotalWeight;
		For Each KeyAndValue IN ExecuteParameters.Ranges Do
			ExecuteParameters.Ranges.Insert(KeyAndValue.Key, Round(KeyAndValue.Value*Factor, 0));
		EndDo;
	EndIf;
	
EndProcedure

// Registers the start of the process.
Procedure ClientMarkBypassStart(ExecuteParameters, CollectionName, Collection = Undefined)
	If Not ExecuteParameters.Interactive Then
		Return;
	EndIf;
	ExecuteParameters.AchievedPercent = ExecuteParameters.AchievedPercent + ExecuteParameters.Range;
	ExecuteParameters.Range = ExecuteParameters.Ranges[CollectionName];
	If Collection <> Undefined Or ExecuteParameters.Property(CollectionName, Collection) Then
		ExecuteParameters.Total = Collection.Count();
		ExecuteParameters.Number = 0;
	Else
		ExecuteParameters.Total = 1;
		ExecuteParameters.Number = 0;
		ClientMarkCollectionBypassProgress(ExecuteParameters, CollectionName);
	EndIf;
EndProcedure

// Registers the progress.
Procedure ClientMarkCollectionBypassProgress(ExecuteParameters, CollectionName)
	If Not ExecuteParameters.Interactive Then
		Return;
	EndIf;
	
	// Registration of the progress.
	ExecuteParameters.Number = ExecuteParameters.Number + 1;
	
	// Check if it is time to transfer the information to the client.
	If CurrentSessionDate() >= ExecuteParameters.Time Then
		// Setting the next time to transfer the information to the client.
		ExecuteParameters.Time = ExecuteParameters.Time + ExecuteParameters.RecordPeriod;
	ElsIf ExecuteParameters.Number = ExecuteParameters.Total Then
		// Output of the last.
	Else
		Return;
	EndIf;
	
	Percent = ExecuteParameters.AchievedPercent
		+ ExecuteParameters.Range*ExecuteParameters.Number/ExecuteParameters.Total;
	
	// Preparing the parameters to be passed.
	If CollectionName = "BeforeSearchingMarkedToDelete" Then
		
		Text = NStr("en='Preparation to search for the objects marked for deletion.';ru='Подготовка к поиску объектов, помеченных на удаление.'");
		
	ElsIf CollectionName = "FindMarkedForDeletion" Then
		
		Text = NStr("en='Search for the objects marked for deletion.';ru='Поиск объектов, помеченных на удаление.'");
		
	ElsIf CollectionName = "AllMarkedForDeletion" Then
		
		Text = NStr("en='Analyzing the objects marked for deletion.';ru='Анализ помеченных на удаление.'");
		
	ElsIf CollectionName = "TechnologicalObjects" Then
		
		Text = NStr("en='Preparation for removal.';ru='Подготовка к удалению.'");
		
	ElsIf CollectionName = "ExclusiveDeletion" Then
		
		Text = NStr("en='Objects deletion in progress.';ru='Выполняется удаление объектов.'");
		
	ElsIf CollectionName = "CustomObjects" Then
		
		NotRemoved = ExecuteParameters.NotRemoved.Count();
		If NotRemoved = 0 Then
			Pattern = NStr("en='Deleted: %1 out of %2 objects.';ru='Удалено: %1 из %2 объектов.'");
		Else
			Pattern = NStr("en='Processed: %1 out of %2 objects, out of this quantity not removed: %3.';ru='Обработано: %1 из %2 объектов, из них не удалено: %3.'");
		EndIf;
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			Pattern,
			Format(ExecuteParameters.Number, "NZ=0; NG="),
			Format(ExecuteParameters.Total, "NZ=0; NG="),
			Format(NOTRemoved, "NZ=0; NG="));
		
	ElsIf CollectionName = "RepeatedlyDeleted" Then
		
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Follow-up check of not deleted objects: %1 out of %2.';ru='Повторная проверка не удаленных объектов: %1 из %2.'"),
			Format(ExecuteParameters.Number, "NZ=0; NG="),
			Format(ExecuteParameters.Total, "NZ=0; NG="));
		
	ElsIf CollectionName = "ImpedingRemoval" Then
		
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Analysis of the objects preventing deletion: %1 out of %2.';ru='Анализ объектов, препятствующих удалению: %1 из %2.'"),
			Format(ExecuteParameters.Number, "NZ=0; NG="),
			Format(ExecuteParameters.Total, "NZ=0; NG="));
		
	Else
		
		Return;
		
	EndIf;
	
	// Registration of the message for reading from the client session.
	LongActions.TellProgress(Percent, Text);
EndProcedure

#EndRegion

#EndIf
