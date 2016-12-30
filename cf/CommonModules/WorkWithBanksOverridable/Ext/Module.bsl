////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// It enables/disables the display of warnings showing the need to update the bank classifier.
//
// Parameters:
//  ShowMessageBox - Boolean.
Procedure OnDeterminingWhetherToShowWarningsAboutOutdatedClassifierBanks(ShowMessageBox) Export
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// SB. SERVICE PROCEDURES AND FUNCTIONS

// Function to be changed and Banks catalog record
// by transferred parameters if such bank is not
// in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - Refs - Array with items of the Structure type - Structure keys - names of
//   the catalog attributes, Structure values - attribute data values
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//   
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function RefreshCreateBanksWIB(Refs, IgnoreManualChanging)
	
	BanksArray = New Array;
	
	For ind = 0 To Refs.UBound() Do
		ParametersObject = Refs[ind];
		Bank = ParametersObject.Bank;
		
		//If ParametersObject.ManualChanging = 1
		//	AND Not IgnoreManualChanging Then
		//	BanksArray.Add(Bank);
		//	Continue;
		//EndIf;
		
		If Bank.IsEmpty() Then
			If ParametersObject.ThisState Then
				BankObject = Catalogs.Banks.CreateFolder();
			Else
				BankObject = Catalogs.Banks.CreateItem();
			EndIf;
		Else
			BankObject = Bank.GetObject();
		EndIf;
		
		FillPropertyValues(BankObject, ParametersObject);
		If Not IsBlankString(ParametersObject.ParentCode) AND Not ValueIsFilled(ParametersObject.Parent) Then
			Region = RefOnBank(ParametersObject.ParentCode, True);
			
			If Not ValueIsFilled(Region) Then
				BanksParametersHigherInHierarchy = New Array;
				BanksParametersHigherInHierarchy.Add(ReferenceOnClassifier(ParametersObject.ParentCode));
				
				// If the transferred Parent is not
				// the root item, then the array of all items (groups) above it in the hierarchy will be returned.
				// The hierarchy root item will be at the beginning of the array, at the end of the array - item transferred in parameters 
				ArrayBanksAboveForHierarchy = BankClassificatorSelection(BanksParametersHigherInHierarchy);
				
				If ArrayBanksAboveForHierarchy.Count() > 0 Then
					// The item transferred to the parameter (to be created) in the returned Array will always be on the last position
					LastItem = ArrayBanksAboveForHierarchy.UBound();
					Region = ArrayBanksAboveForHierarchy[LastItem];
				EndIf;
			EndIf;
			
			If ValueIsFilled(Region) AND Region.IsFolder Then
				BankObject.Parent = Region;
			EndIf;
			
			If Not ValueIsFilled(BankObject.Parent) Then
				EventName = ?(EventName = "",
					NStr("en='Pick from ACC';ru='Подбор из классификатора'"), EventName);
				ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Failed to obtain the parent from the item with BIC %1';ru='Не смогли получить родителя у элемента с БИК %1'"), TrimAll(ParametersObject.Code));
				WriteLogEvent(EventName, 
					EventLogLevel.Error,,, ErrorText);
				Break;
			EndIf;
		EndIf;
		
		BeginTransaction();
		Try
			BankObject.Write();
			CommitTransaction();
		Except
			RollbackTransaction();
			
			EventName = ?(EventName = "",
				NStr("en='Pick from ACC';ru='Подбор из классификатора'"), EventName);
			WriteLogEvent(EventName, 
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
			Break;
		EndTry;
		
		BanksArray.Add(BankObject.Ref);
	EndDo;
	
	Return BanksArray;
	
EndFunction

// The function selects the classifier data to be copied to
// the Banks catalog item if such bank is
// not in the base, it is created if the bank is not on the first level in the hierarchy, the whole chain of parents is created/copied
//
// Parameters:
//
// - BankReferences - Array with items of CatalogRef.RFBanksClassifier type - the list
//   of classifier values to be processed
// - IgnoreManualChanging - Boolean - do not process banks changed manually
//
// Returns:
//
// - Array with items of CatalogRef.Banks type
//
Function BankClassificatorSelection(Val ReferencesBanks, IgnoreManualChanging = False) Export
	
	BanksArray = New Array;
	
	If ReferencesBanks.Count() = 0 Then
		Return BanksArray;
	EndIf;
	
	LinksHierarchy = SupplementArrayWithRefParents(ReferencesBanks);
	
	Query = New Query;
	Query.SetParameter("LinksHierarchy", LinksHierarchy);
	Query.Text =
	"SELECT
	|	RFBankClassifier.Code AS BIN,
	|	RFBankClassifier.CorrAccount AS CorrAccount,
	|	RFBankClassifier.Description,
	|	RFBankClassifier.City,
	|	RFBankClassifier.Address,
	|	RFBankClassifier.PhoneNumbers,
	|	RFBankClassifier.IsFolder,
	|	RFBankClassifier.Parent.Code
	|INTO TU_RFBankClassifier
	|FROM
	|	Catalog.RFBankClassifier AS RFBankClassifier
	|WHERE
	|	RFBankClassifier.Ref IN(&LinksHierarchy)
	|
	|INDEX BY
	|	BIN,
	|	CorrAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Bank,
	|	TU_RFBankClassifier.BIN AS Code,
	|	TU_RFBankClassifier.CorrAccount AS CorrAccount,
	|	TU_RFBankClassifier.IsFolder AS ThisState,
	|	TU_RFBankClassifier.Description,
	|	TU_RFBankClassifier.City,
	|	TU_RFBankClassifier.Address,
	|	TU_RFBankClassifier.PhoneNumbers,
	|	ISNULL(TU_RFBankClassifier.ParentCode, """") AS ParentCode
	|INTO BanksWithoutParents
	|FROM
	|	TU_RFBankClassifier AS TU_RFBankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_RFBankClassifier.CorrAccount = Banks.CorrAccount
	|			AND TU_RFBankClassifier.BIN = Banks.Code
	|WHERE
	|	NOT TU_RFBankClassifier.IsFolder
	|
	|UNION ALL
	|
	|SELECT
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)),
	|	TU_RFBankClassifier.BIN,
	|	NULL,
	|	TU_RFBankClassifier.IsFolder,
	|	TU_RFBankClassifier.Description,
	|	NULL,
	|	NULL,
	|	NULL,
	|	ISNULL(TU_RFBankClassifier.ParentCode, """")
	|FROM
	|	TU_RFBankClassifier AS TU_RFBankClassifier
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON TU_RFBankClassifier.BIN = Banks.Code
	|WHERE
	|	TU_RFBankClassifier.IsFolder
	|
	|INDEX BY
	|	ParentCode
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BanksWithoutParents.Bank,
	|	BanksWithoutParents.Code AS Code,
	|	BanksWithoutParents.CorrAccount,
	|	BanksWithoutParents.ThisState AS ThisState,
	|	BanksWithoutParents.Description,
	|	BanksWithoutParents.City,
	|	BanksWithoutParents.Address,
	|	BanksWithoutParents.PhoneNumbers,
	|	BanksWithoutParents.ParentCode,
	|	ISNULL(Banks.Ref, VALUE(Catalog.Banks.EmptyRef)) AS Parent
	|FROM
	|	BanksWithoutParents AS BanksWithoutParents
	|		LEFT JOIN Catalog.Banks AS Banks
	|		ON BanksWithoutParents.ParentCode = Banks.Parent
	|
	|ORDER BY
	|	ThisState DESC,
	|	Code";
	
	SetPrivilegedMode(True);
	BanksTable = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	Refs = New Array;
	For Each ValueTableRow IN BanksTable Do
		
		ObjectParameters = CommonUse.ValueTableRowToStructure(ValueTableRow);
		DeleteNoValidKeysStructure(ObjectParameters);
		Refs.Add(ObjectParameters);
		
	EndDo;
	
	BanksArray = RefreshCreateBanksWIB(Refs, IgnoreManualChanging);
	
	Return BanksArray;
	
EndFunction

// Receiving the references to the RF Bank Classifier catalog item by BIC or CorrAccount text presentation
// 
Function ReferenceOnClassifier(BIN, CorrAccount = "")
	
	If BIN = "" Then
		Return Catalogs.RFBankClassifier.EmptyRef();
	EndIf;
	
	Query = New Query;
	QueryText =
	"SELECT
	|	RFBankClassifier.Ref
	|FROM
	|	Catalog.RFBankClassifier AS RFBankClassifier
	|WHERE
	|	RFBankClassifier.Code = &BIN
	|	AND RFBankClassifier.CorrAccount = &CorrAccount";
	
	Query.SetParameter("BIN", BIN);
	
	If CorrAccount = "" Then
		QueryText = StrReplace(QueryText, "AND RFBankClassifier.CorrAccount = &CorrAccount", "");
	Else
		Query.SetParameter("CorrAccount", CorrAccount);
	EndIf;
	
	Query.Text = QueryText;
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.RFBankClassifier.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction // ReferenceOnClassifier()

// Receiving the references to
// the Banks catalog item by BIC or CorrAccount text presentation
//
Function RefOnBank(BIN, ThisState = False)
	
	If BIN = "" Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Banks.Ref
	|FROM
	|	Catalog.Banks AS Banks
	|WHERE
	|	Banks.Code = &BIN
	|	AND Banks.IsFolder = &IsFolder";
	
	Query.SetParameter("BIN",       BIN);
	Query.SetParameter("IsFolder", ThisState);
	
	SetPrivilegedMode(True);
	Result = Query.Execute();
	SetPrivilegedMode(False);
	
	If Result.IsEmpty() Then
		Return Catalogs.Banks.EmptyRef();
	EndIf;
	
	Return Result.Unload()[0].Ref;
	
EndFunction // RefsOnBank()

Function SupplementArrayWithRefParents(Val Refs)
	
	TableName = Refs[0].Metadata().FullName();
	
	RefArray = New Array;
	For Each Ref IN Refs Do
		RefArray.Add(Ref);
	EndDo;
	
	CurrentRefs = Refs;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Table.Parent AS Ref
	|FROM
	|	" + TableName + " AS
	|Table
	|WHERE Table.Reference
	|	In (&Links) And Table.Parent <> VALUE(" + TableName + ".EmptyRef)";
	
	While True Do
		Query.SetParameter("Refs", CurrentRefs);
		Result = Query.Execute();
		If Result.IsEmpty() Then
			Break;
		EndIf;
		
		CurrentRefs = New Array;
		Selection = Result.Select();
		While Selection.Next() Do
			CurrentRefs.Add(Selection.Ref);
			RefArray.Add(Selection.Ref);
		EndDo;
	EndDo;
	
	Return RefArray;
	
EndFunction

Procedure DeleteNoValidKeysStructure(ParametersStructureCatalog)
	
	For Each KeyAndValue IN ParametersStructureCatalog Do
		If KeyAndValue.Value = Null OR KeyAndValue.Key = "IsFolder" Then
			ParametersStructureCatalog.Delete(KeyAndValue.Key);
		EndIf;
	EndDo;
	
EndProcedure

// It loads the bank classifier in the service model from the provided data
//
// Parameters:
//   PathToFile - String - bnk.zip file path received from the provided data
//
Function ImportSuppliedRFBankClassifier(PathToFile) Export
	
	Return WorkWithBanks.ImportDataFromRBKFile(PathToFile);
	
EndFunction



