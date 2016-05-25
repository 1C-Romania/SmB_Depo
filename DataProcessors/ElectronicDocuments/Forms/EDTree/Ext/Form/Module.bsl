////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
Procedure FillIdentifierOfListRowsTree()
	
	IdentifierList.Clear();
	For Each TreeItem IN TreeSubordinateED.GetItems() Do
		If TreeItem.ActualED AND Not TreeItem.EDStatus = Enums.EDStatuses.Rejected Then
			IdentifierList.Add(TreeItem.GetID());
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ExpandRow()
	
	If IdentifierList.Count()=0 Then
		FillIdentifierOfListRowsTree();
	EndIf;
	
	For Each String IN IdentifierList Do
		Items.TreeSubordinateED.CurrentRow = String.Value;
		Items.TreeSubordinateED.Expand(Items.TreeSubordinateED.CurrentRow, True);
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshWoodED()

	SetPrivilegedMode(True);
	
	ExchangeSettings = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(ObjectRef, False);
	GenerateTreesED();

EndProcedure

// For TRAD12, a root tree element
// is a primary ED - seller title. The actual
// EDStatus register record can refer to the TRAD12 (customer title).
// IN order to biuld the tree correctly,
// it is necessary to get a root element on current ED.
//
&AtServer
Function EDOwner(Val CurrentED)
	
	ReturnValue = CurrentED;
	
	If CurrentED.EDKind = Enums.EDKinds.TORG12Customer
		OR CurrentED.EDKind = Enums.EDKinds.ActCustomer
		OR CurrentED.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient Then
		
		ReturnValue = CurrentED.ElectronicDocumentOwner;
	EndIf;

	Return ReturnValue;
	
EndFunction

&AtServer
Function EDKindsArrayWoodRootElements()
	
	EDKindsList = New Array;
	EDKindsList.Add(Enums.EDKinds.TORG12Seller);
	EDKindsList.Add(Enums.EDKinds.ActPerformer);
	EDKindsList.Add(Enums.EDKinds.AgreementAboutCostChangeSender);
	EDKindsList.Add(Enums.EDKinds.CustomerInvoiceNote);
	EDKindsList.Add(Enums.EDKinds.TORG12);
	EDKindsList.Add(Enums.EDKinds.AcceptanceCertificate);
	
	Return EDKindsList;
	
EndFunction

&AtServer
Function EDKindsArrayIsNotDisplayedInTree()
	
	EDKindsList = New Array;
	EDKindsList.Add(Enums.EDKinds.AddData);
	
	Return EDKindsList;
	
EndFunction

// Procedure adds irrelevant primary EDs
// with full subordination structure in the tree.
&AtServer
Procedure DisplayNotTopicalED(ObjectTree, ActualED)

	Query = New Query;
	Query.Text =
		"SELECT
		|	EDAttachedFiles.Ref AS Ref,
		|	EDAttachedFiles.FileOwner
		|FROM
		|	Catalog.EDAttachedFiles AS EDAttachedFiles
		|WHERE
		|	EDAttachedFiles.FileOwner = &EDOwner
		|	AND Not EDAttachedFiles.EDKind IN (&TypesOfEDExceptions)
		|	AND EDAttachedFiles.ElectronicDocumentOwner = VALUE(Catalog.EDAttachedFiles.EmptyRef)
		|	AND EDAttachedFiles.Ref <> &ActualED";

	Query.SetParameter("EDOwner", ObjectRef);
	Query.SetParameter("EDKindsList", EDKindsArrayWoodRootElements());
	Query.SetParameter("TypesOfEDExceptions", EDKindsArrayIsNotDisplayedInTree());
	Query.SetParameter("ActualED", ActualED);

	Result = Query.Execute();

	Selection = Result.Select();

	While Selection.Next() Do
		RootElement = Undefined;
		PrepopulatingTree(Selection.Ref, ObjectTree, False, RootElement);
		If ValueIsFilled(RootElement) Then
			OutputSubordinateDocuments(Selection.FileOwner, RootElement, Selection.Ref);
		EndIf;
	EndDo;

	ObjectTree.Rows.Sort("Version");
	
EndProcedure

&AtServer
Procedure FillInInformationInEmptyLines(ObjectTree)
	
	ParametersStructure = New Structure;
	For Each String IN ObjectTree.Rows Do
		If Not ValueIsFilled(String.Ref) Then
			String.Presentation = ElectronicDocumentsService.DetermineEDPresentation(String.EDKind, ParametersStructure);
			String.EDStatus = Enums.EDStatuses[?(String.EDDirection = Enums.EDDirections.Outgoing, "NotFormed", "NotReceived")];
		EndIf;
		If String.Rows.Count() > 0 Then
			FillInInformationInEmptyLines(String);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateTreesED()

	TreeSubordinateED.GetItems().Clear();

	RefArray = New Array;
	RefArray.Add(ObjectRef);
	
	AccordanceOfEDIOwners = ElectronicDocumentsServiceCallServer.GetCorrespondenceOwnersAndED(RefArray);
	
	ObjectTree = FormAttributeToValue("TreeSubordinateED");
	If AccordanceOfEDIOwners.Count() > 0 Then
		For Each Item IN AccordanceOfEDIOwners Do
			ActualED = "";
			If ValueIsFilled(Item.Value) Then
				If Not ValueIsFilled(ExchangeSettings) Then
					ExchangeSettings = ElectronicDocumentsService.DetermineEDExchangeSettingsBySource(
						ObjectRef, False, , Item.Value, , False);
				EndIf;
				ActualED = EDOwner(Item.Value);
				RootElement = Undefined;
				PrepopulatingTree(ActualED, ObjectTree, True, RootElement);
				If Not RootElement = Undefined Then
					OutputSubordinateDocuments(ObjectRef, RootElement, ActualED);
				EndIf;
			ElsIf ValueIsFilled(ExchangeSettings) Then
				ParametersStructure = New Structure;
				ParametersStructure.Insert("EDKind",               ExchangeSettings.EDKind);
				ParametersStructure.Insert("EDDirection",       ExchangeSettings.EDDirection);
				ParametersStructure.Insert("EDFScheduleVersion", ExchangeSettings.EDFScheduleVersion);
				ParametersStructure.Insert("EDStatus",            Enums.EDStatuses.EmptyRef());
				ParametersStructure.Insert("EDFProfileSettings",  ExchangeSettings.EDFProfileSettings);
				ParametersStructure.Insert("EDAgreement",        ExchangeSettings.EDAgreement);
				
				PrepopulatingTree(ParametersStructure, ObjectTree, False);
			Else
				Return;
			EndIf;
		EndDo;
		
		DisplayNotTopicalED(ObjectTree, ActualED);
		
		If ValueIsFilled(ActualED) Then
			ParametersOfActualED = CommonUse.ObjectAttributesValues(ActualED,
				"EDStatus, EDFScheduleVersion, EDKind, EDDirection, EDAgreement");
			If ParametersOfActualED.EDStatus = Enums.EDStatuses.RejectedByReceiver
				AND Not ParametersOfActualED.EDKind = Enums.EDKinds.CustomerInvoiceNote
				AND Not ParametersOfActualED.EDKind = Enums.EDKinds.CorrectiveInvoiceNote Then
				
				ParametersStructure = New Structure;
				ParametersStructure.Insert("EDKind",               ParametersOfActualED.EDKind);
				ParametersStructure.Insert("EDDirection",       ParametersOfActualED.EDDirection);
				ParametersStructure.Insert("EDFScheduleVersion", ParametersOfActualED.EDFScheduleVersion);
				ParametersStructure.Insert("EDStatus",            Enums.EDStatuses.EmptyRef());
				ParametersStructure.Insert("EDAgreement",        ParametersOfActualED.EDAgreement);
				
				PrepopulatingTree(ParametersStructure, ObjectTree, False);
			EndIf;
		EndIf;
		
		ProcessTree(ObjectTree);
		
		FillInInformationInEmptyLines(ObjectTree);
		ValueToFormAttribute(ObjectTree, "TreeSubordinateED");
		FillIdentifierOfListRowsTree();
		
		FillIDIndex(TreeSubordinateED);
		
	EndIf;

EndProcedure

&AtServer
Procedure FillIDIndex(EDTree)
	
	For Each TreeItem IN EDTree.GetItems() Do
		
		If TreeItem.Ref = InitialDocument Then
			IndexID = TreeItem.GetID();
		EndIf;
		
		If TreeItem.GetItems().Count() > 0 Then
			 FillIDIndex(TreeItem);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FindED()
	
	Items.TreeSubordinateED.CurrentRow = IndexID;
	
EndProcedure

&AtServer
Procedure PrepopulatingTree(ED, ObjectTree, ThisCurrentED, RootElement = Undefined)
	
	If ValueIsFilled(ExchangeSettings) AND ExchangeSettings.Property("EDAgreement") Then
		ExchangeThroughOperator = (ExchangeSettings.EDExchangeMethod = Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
		PackageFormatVersion = ExchangeSettings.PackageFormatVersion;
		RootElement = Undefined;
		If ExchangeThroughOperator AND (ED.EDKind = Enums.EDKinds.CustomerInvoiceNote
			OR ED.EDKind = Enums.EDKinds.CorrectiveInvoiceNote) Then
		
			RowESF                = ObjectTree.Rows.Add();
			RowESF.EDType          = Enums.EDVersionElementTypes.ESF;
			RowESF.EDKind          = ED.EDKind;
			RowESF.EDDirection  = ED.EDDirection;
			RowESF.RowIsAvailable = True;
			RowESF.ActualED   = ThisCurrentED;
			RootElement = RowESF;
			
			If ED.EDDirection = Enums.EDDirections.Incoming Then
				
				RowPDO                 = RowESF.Rows.Add();
				RowPDO.EDType           = Enums.EDVersionElementTypes.EISDC;
				RowPDO.EDKind           = Enums.EDKinds.Confirmation;
				RowPDO.EDDirection   = Enums.EDDirections.Incoming;
				
				RowIP                  = RowESF.Rows.Add();
				RowIP.EDType            = Enums.EDVersionElementTypes.NAREI;
				RowIP.EDKind            = Enums.EDKinds.NotificationAboutReception;
				RowIP.EDDirection    = Enums.EDDirections.Outgoing;
				
				NewRow               = RowPDO.Rows.Add();
				NewRow.EDType         = Enums.EDVersionElementTypes.NRCDDEI;
				NewRow.EDKind         = Enums.EDKinds.NotificationAboutReception;
				NewRow.EDDirection = Enums.EDDirections.Outgoing;
				
				RowPDOIP               = RowIP.Rows.Add();
				RowPDOIP.EDType         = Enums.EDVersionElementTypes.SDANAREIC;
				RowPDOIP.EDKind         = Enums.EDKinds.Confirmation;
				RowPDOIP.EDDirection = Enums.EDDirections.Incoming;
				
				NewRow               = RowPDOIP.Rows.Add();
				NewRow.EDType         = Enums.EDVersionElementTypes.NRCDDNREI;
				NewRow.EDKind         = Enums.EDKinds.NotificationAboutReception;
				NewRow.EDDirection = Enums.EDDirections.Outgoing;
				
				If ED.EDStatus = Enums.EDStatuses.Rejected Then
					
					RowUU                  = RowESF.Rows.Add();
					RowUU.EDType            = Enums.EDVersionElementTypes.NAEIC;
					RowUU.EDKind            = Enums.EDKinds.NotificationAboutClarification;
					RowUU.EDDirection    = Enums.EDDirections.Outgoing;
					NewRow               = RowUU.Rows.Add();
					NewRow.EDType         = Enums.EDVersionElementTypes.NRNCEI;
					NewRow.EDKind         = Enums.EDKinds.NotificationAboutReception;
					NewRow.EDDirection = Enums.EDDirections.Incoming;
					
				EndIf;
				
			Else
				
				RowOfPDP                 = RowESF.Rows.Add();
				RowOfPDP.EDType           = Enums.EDVersionElementTypes.EIRDC;
				RowOfPDP.EDKind           = Enums.EDKinds.Confirmation;
				RowOfPDP.EDDirection   = Enums.EDDirections.Incoming;
				
				NewRow               = RowOfPDP.Rows.Add();
				NewRow.EDType         = Enums.EDVersionElementTypes.NRCDREI;
				NewRow.EDKind         = Enums.EDKinds.NotificationAboutReception;
				NewRow.EDDirection = Enums.EDDirections.Outgoing;
				
				NewRow               = RowESF.Rows.Add();
				NewRow.EDType         = Enums.EDVersionElementTypes.NAREI;
				NewRow.EDKind         = Enums.EDKinds.NotificationAboutReception;
				NewRow.EDDirection = Enums.EDDirections.Incoming;
				
				If ED.EDStatus = Enums.EDStatuses.Rejected OR ED.EDStatus = Enums.EDStatuses.RejectedByReceiver Then
					
					RowUU                  = RowESF.Rows.Add();
					RowUU.EDType            = Enums.EDVersionElementTypes.NAEIC;
					RowUU.EDKind            = Enums.EDKinds.NotificationAboutClarification;
					RowUU.EDDirection    = Enums.EDDirections.Incoming;
					
					NewRow               = RowUU.Rows.Add();
					NewRow.EDType         = Enums.EDVersionElementTypes.NRNCEI;
					NewRow.EDKind         = Enums.EDKinds.NotificationAboutReception;
					NewRow.EDDirection = Enums.EDDirections.Outgoing;
					
				EndIf;
				
			EndIf;
		ElsIf ED.EDKind = Enums.EDKinds.TORG12Seller
			OR ED.EDKind = Enums.EDKinds.ActPerformer
			OR ED.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender Then
			
			ViewOfOncomingED = Enums.EDKinds.TORG12Customer;
			If ED.EDKind = Enums.EDKinds.ActPerformer Then
				
				ViewOfOncomingED = Enums.EDKinds.ActCustomer;
			ElsIf ED.EDKind = Enums.EDKinds.AgreementAboutCostChangeSender Then
				
				ViewOfOncomingED = Enums.EDKinds.AgreementAboutCostChangeRecipient;
			EndIf;
			
			RowSeller                = ObjectTree.Rows.Add();
			RowSeller.EDType          = Enums.EDVersionElementTypes.PrimaryED;
			RowSeller.EDKind          = ED.EDKind;
			RowSeller.EDDirection  = ED.EDDirection;
			RowSeller.RowIsAvailable = True;
			RowSeller.ActualED   = ThisCurrentED;
			RootElement = RowSeller;
			
			If ExchangeThroughOperator
				Or PackageFormatVersion = Enums.EDPackageFormatVersions.Version30 Then
				
				If ED.EDDirection = Enums.EDDirections.Incoming Then
					
					RowIP                  = RowSeller.Rows.Add();
					RowIP.EDType            = Enums.EDVersionElementTypes.RN;
					RowIP.EDKind            = Enums.EDKinds.NotificationAboutReception;
					RowIP.EDDirection    = Enums.EDDirections.Outgoing;
					
					RowCustomer          = RowSeller.Rows.Add();
					RowCustomer.EDType    = Enums.EDVersionElementTypes.PrimaryED;
					RowCustomer.EDKind    = ViewOfOncomingED;
					RowCustomer.EDDirection = Enums.EDDirections.Outgoing;
					
					// Service document set changing in accordance with rule version use.
					If ED.EDFScheduleVersion <> Enums.Exchange1CRegulationsVersion.Version20
						 AND ExchangeThroughOperator Then
						
						NewRow               = RowCustomer.Rows.Add();
						NewRow.EDType         = Enums.EDVersionElementTypes.RDC;
						NewRow.EDKind         = Enums.EDKinds.Confirmation;
						NewRow.EDDirection = Enums.EDDirections.Incoming;
						
						RowIP                  = RowCustomer.Rows.Add();
						RowIP.EDType            = Enums.EDVersionElementTypes.RN;
						RowIP.EDKind            = Enums.EDKinds.NotificationAboutReception;
						RowIP.EDDirection    = Enums.EDDirections.Incoming;
					EndIf;
					
					If ED.EDStatus = Enums.EDStatuses.Rejected Then
						
						RowUU                  = RowSeller.Rows.Add();
						RowUU.EDType            = Enums.EDVersionElementTypes.NAC;
						RowUU.EDKind            = Enums.EDKinds.NotificationAboutClarification;
						RowUU.EDDirection    = Enums.EDDirections.Outgoing;
					EndIf;
				Else
					
					If ExchangeThroughOperator Then
						RowPDO                 = RowSeller.Rows.Add();
						RowPDO.EDType           = Enums.EDVersionElementTypes.RDC;
						RowPDO.EDKind           = Enums.EDKinds.Confirmation;
						RowPDO.EDDirection   = Enums.EDDirections.Incoming;
					EndIf;
					
					RowIP                  = RowSeller.Rows.Add();
					RowIP.EDType            = Enums.EDVersionElementTypes.RN;
					RowIP.EDKind            = Enums.EDKinds.NotificationAboutReception;
					RowIP.EDDirection    = Enums.EDDirections.Incoming;
					
					RowCustomer          = RowSeller.Rows.Add();
					RowCustomer.EDType    = Enums.EDVersionElementTypes.PrimaryED;
					RowCustomer.EDKind    = ViewOfOncomingED;
					RowCustomer.EDDirection = Enums.EDDirections.Incoming;
					
					// Service document set changing in accordance with rule version use.
					If ValueIsFilled(ED.EDFScheduleVersion) 
						AND ED.EDFScheduleVersion <> Enums.Exchange1CRegulationsVersion.Version20 Then
						RowIP                  = RowCustomer.Rows.Add();
						RowIP.EDType            = Enums.EDVersionElementTypes.RN;
						RowIP.EDKind            = Enums.EDKinds.NotificationAboutReception;
						RowIP.EDDirection    = Enums.EDDirections.Outgoing;
					EndIf;
					
					If ED.EDStatus = Enums.EDStatuses.Rejected OR ED.EDStatus = Enums.EDStatuses.RejectedByReceiver Then
						
						RowUU                  = RowSeller.Rows.Add();
						RowUU.EDType            = Enums.EDVersionElementTypes.NAC;
						RowUU.EDKind            = Enums.EDKinds.NotificationAboutClarification;
						RowUU.EDDirection    = Enums.EDDirections.Incoming;
					EndIf;
				EndIf;
			Else
				RowCustomer          = RowSeller.Rows.Add();
				RowCustomer.EDType    = Enums.EDVersionElementTypes.PrimaryED;
				RowCustomer.EDKind    = ViewOfOncomingED;
				RowCustomer.EDDirection = ?(ED.EDDirection = Enums.EDDirections.Incoming,
					Enums.EDDirections.Outgoing, Enums.EDDirections.Incoming);
			EndIf;
		ElsIf ED.EDKind = Enums.EDKinds.TORG12
			OR ED.EDKind = Enums.EDKinds.RightsDelegationAct
			OR ED.EDKind = Enums.EDKinds.AcceptanceCertificate Then
		
			RowSeller                = ObjectTree.Rows.Add();
			RowSeller.EDType          = Enums.EDVersionElementTypes.PrimaryED;
			RowSeller.EDKind          = ED.EDKind;
			RowSeller.EDDirection  = ED.EDDirection;
			RowSeller.RowIsAvailable = True;
			RowSeller.ActualED   = ThisCurrentED;
			RootElement = RowSeller;
			
			If ExchangeThroughOperator Then
				If ED.EDDirection = Enums.EDDirections.Incoming Then
					
					RowIP                  = RowSeller.Rows.Add();
					RowIP.EDType            = Enums.EDVersionElementTypes.RN;
					RowIP.EDKind            = Enums.EDKinds.NotificationAboutReception;
					RowIP.EDDirection    = Enums.EDDirections.Outgoing;
					
					If ED.EDStatus = Enums.EDStatuses.Rejected Then
						
						RowUU                  = RowSeller.Rows.Add();
						RowUU.EDType            = Enums.EDVersionElementTypes.NAC;
						RowUU.EDKind            = Enums.EDKinds.NotificationAboutClarification;
						RowUU.EDDirection    = Enums.EDDirections.Outgoing;
					EndIf;
					
				Else
					RowPDO                 = RowSeller.Rows.Add();
					RowPDO.EDType           = Enums.EDVersionElementTypes.RDC;
					RowPDO.EDKind           = Enums.EDKinds.Confirmation;
					RowPDO.EDDirection   = Enums.EDDirections.Incoming;
					
					RowIP                  = RowSeller.Rows.Add();
					RowIP.EDType            = Enums.EDVersionElementTypes.RN;
					RowIP.EDKind            = Enums.EDKinds.NotificationAboutReception;
					RowIP.EDDirection    = Enums.EDDirections.Incoming;
					
					If ED.EDStatus = Enums.EDStatuses.Rejected OR ED.EDStatus = Enums.EDStatuses.RejectedByReceiver Then
						
						RowUU                  = RowSeller.Rows.Add();
						RowUU.EDType            = Enums.EDVersionElementTypes.NAC;
						RowUU.EDKind            = Enums.EDKinds.NotificationAboutClarification;
						RowUU.EDDirection    = Enums.EDDirections.Incoming;
						
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		If RootElement <> Undefined AND (ED.EDStatus = Enums.EDStatuses.Canceled
			OR ED.EDStatus = Enums.EDStatuses.CancellationOfferCreated
			OR ED.EDStatus = Enums.EDStatuses.CancellationOfferReceived) Then
			
			ATAString                  = RootElement.Rows.Add();
			ATAString.EDType            = Enums.EDVersionElementTypes.ATA;
			ATAString.EDKind            = Enums.EDKinds.CancellationOffer;
			ATAString.EDDirection    = Enums.EDDirections.Incoming;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessTree(ObjectTree)
	
	For Each String IN ObjectTree.Rows Do
		
		If Not ValueIsFilled(String.Ref) Then
			
			If (NOT ValueIsFilled(String.Parent) OR ValueIsFilled(String.Parent.Ref))
				AND String.EDDirection = Enums.EDDirections.Outgoing
				AND String.EDKind <> Enums.EDKinds.TORG12Customer
				AND String.EDKind <> Enums.EDKinds.ActCustomer
				AND String.EDKind <> Enums.EDKinds.AgreementAboutCostChangeRecipient Then
				
				String.ExpectedAction = Enums.EDExpectedAction.Generate;
			EndIf;
		Else
			If Not CommonUse.GetAttributeValue(String.Ref, "DeletionMark") Then
				String.ExpectedAction = GetExpectedCurrentStatusAction(String);
			EndIf;
		EndIf;
		
		String.ExpectedCounterpartyAction = GetExpectedCounterpartyAction(String);
		String.RowIsAvailable = ?(ValueIsFilled(String.ExpectedAction), True, False);
		String.Presentation = StrReplace(String.Presentation, "_", " ");
		
		If String.Rows.Count() > 0 Then
			ProcessTree(String);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function GetExpectedCurrentStatusAction(String)
	
	ReturnValue = Enums.EDExpectedAction.EmptyRef();
	
	EDStatus = ElectronicDocumentsService.DetermineVersionStateByEDStatus(String.Ref);
	If EDStatus = Enums.EDVersionsStates.ExchangeCompleted
		Or EDStatus = Enums.EDVersionsStates.ExchangeCompletedWithCorrection
		Or EDStatus = Enums.EDVersionsStates.NotificationAboutReceivingExpected  Then
		
		Return ReturnValue;
	EndIf;

	CurrentStatusOfED = String.EDStatus;
	IsServiceED = (String.EDKind = Enums.EDKinds.NotificationAboutReception
		OR String.EDKind = Enums.EDKinds.Confirmation
		OR String.EDKind = Enums.EDKinds.NotificationAboutClarification);
	
	If CurrentStatusOfED = Enums.EDStatuses.TransferError Then
		
	ElsIf CurrentStatusOfED = Enums.EDStatuses.Rejected
		OR CurrentStatusOfED = Enums.EDStatuses.RejectedByReceiver Then
	ElsIf String.EDKind = Enums.EDKinds.CancellationOffer
		AND CurrentStatusOfED = Enums.EDStatuses.Received Then
		ReturnValue = Enums.EDExpectedAction.Accept;
	Else
		ConfiguringExchangeForStatuses = ElectronicDocumentsService.EDExchangeSettings(String.Ref);
		EDStatusesArray = ElectronicDocumentsService.ReturnEDStatusesArray(ConfiguringExchangeForStatuses);
		
		If EDStatusesArray.Count() > 0 Then
			CurrentStatusIndex = EDStatusesArray.Find(CurrentStatusOfED);
			If CurrentStatusIndex <> Undefined Then
				
				If CurrentStatusIndex + 1 < EDStatusesArray.Count() Then
					NextStatus = EDStatusesArray[CurrentStatusIndex + 1];
					
					If CurrentStatusOfED = Enums.EDStatuses.Created
						OR CurrentStatusOfED = Enums.EDStatuses.Received Then
						
						ReturnValue = Enums.EDExpectedAction.Approve;
						If Not (NOT ElectronicDocumentsService.ImmediateEDSending()
								OR ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseDigitalSignatures")) Then
								
							ReturnValue = Enums.EDExpectedAction.ApproveSend;
						EndIf;
						
					ElsIf CurrentStatusOfED = Enums.EDStatuses.Approved Then
						If NextStatus = Enums.EDStatuses.DigitallySigned Then
							
							ReturnValue = Enums.EDExpectedAction.Sign;
							If ElectronicDocumentsService.ImmediateEDSending() Then
								ReturnValue = Enums.EDExpectedAction.SignSend;
							EndIf;
						ElsIf NextStatus = Enums.EDStatuses.PreparedToSending Then
							
							ReturnValue = Enums.EDExpectedAction.Send;
						EndIf;
					ElsIf CurrentStatusOfED = Enums.EDStatuses.PreparedToSending Then
						
						If NextStatus = Enums.EDStatuses.Delivered Then
							ReturnValue = Enums.EDExpectedAction.EmptyRef();
						Else
							ReturnValue = Enums.EDExpectedAction.Send;
						EndIf;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

&AtServer
Function GetExpectedCounterpartyAction(String)
	
	ReturnValue = "";
	
	VersionEDStatus = ElectronicDocumentsService.DetermineVersionStateByEDStatus(String.Ref);
	If VersionEDStatus = Enums.EDVersionsStates.ExchangeCompleted
		Or VersionEDStatus = Enums.EDVersionsStates.ExchangeCompletedWithCorrection
		Or VersionEDStatus = Enums.EDVersionsStates.NotificationOnSigning Then
		
		Return ReturnValue;
	EndIf;

	
	If String.EDKind = Enums.EDKinds.NotificationAboutReception
		OR String.EDKind = Enums.EDKinds.Confirmation
		OR String.EDKind = Enums.EDKinds.NotificationAboutClarification Then
		
		If String.EDKind = Enums.EDKinds.Confirmation AND Not ValueIsFilled(String.Ref)
			AND ValueIsFilled(String.Parent.Ref)
			AND (String.Parent.EDStatus = Enums.EDStatuses.TransferedToOperator
			OR String.Parent.EDStatus = Enums.EDStatuses.Sent
			OR String.Parent.EDStatus = Enums.EDStatuses.Received
			OR String.Parent.EDStatus = Enums.EDStatuses.Delivered) Then
			
			ReturnValue = NStr("en = 'EDF operator confirmations'");
		ElsIf (String.EDType = Enums.EDVersionElementTypes.NRNCEI
				OR String.EDType = Enums.EDVersionElementTypes.NAREI)
				AND String.EDDirection = Enums.EDDirections.Incoming
				AND ValueIsFilled(String.Parent.Ref) AND (String.Parent.EDStatus = Enums.EDStatuses.Sent
					OR String.Parent.EDStatus = Enums.EDStatuses.TransferedToOperator
					OR String.Parent.EDStatus = Enums.EDStatuses.Delivered)
				AND Not ValueIsFilled(String.Ref) Then
			
			ReturnValue = NStr("en = 'Acceptance notification'");
		EndIf;
		
	Else
		If String.EDStatus = Enums.EDStatuses.TransferedToOperator Then
			
			ReturnValue = NStr("en = 'Sending confirmations'");
			
			// Changing in the tree behavior for the version of rule 20.
			If String.Ref.EDFScheduleVersion = Enums.Exchange1CRegulationsVersion.Version20
				AND (String.EDKind = Enums.EDKinds.TORG12Customer
				OR String.EDKind = Enums.EDKinds.ActCustomer
				OR String.EDKind = Enums.EDKinds.AgreementAboutCostChangeRecipient) Then
				
				ReturnValue = "";
			EndIf;
		ElsIf String.EDStatus = Enums.EDStatuses.Sent Then
			
			ReturnValue = NStr("en = 'Delivery confirmation'");
		EndIf;
	EndIf;
	
	Return ReturnValue;
	
EndFunction

&AtServer
Procedure OutputSubordinateDocuments(CurrentDocument, ParentalTree, ActualED = Undefined)

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	AttachedFiles.Ref,
	|	AttachedFiles.EDStatus,
	|	AttachedFiles.EDVersionNumber,
	|	AttachedFiles.EDStatusChangeDate,
	|	AttachedFiles.EDDirection,
	|	AttachedFiles.Presentation,
	|	AttachedFiles.DeletionMark,
	|	CASE
	|		WHEN SlaveBoundFiles.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ExistenceOfSubordinateDocuments,
	|	AttachedFiles.SenderDocumentDate AS OwnerDate,
	|	AttachedFiles.SenderDocumentNumber AS OwnerNumber,
	|	AttachedFiles.EDKind,
	|	AttachedFiles.VersionPointTypeED AS EDType,
	|	CASE
	|		WHEN AttachedFiles.EDKind IN (&EDKindsList)
	|			THEN CASE
	|					WHEN AttachedFiles.EDDirection = VALUE(Enum.EDDirections.Outgoing)
	|						THEN AttachedFiles.CreationDate
	|					ELSE AttachedFiles.EDFormingDateBySender
	|				END
	|		ELSE UNDEFINED
	|	END AS Version
	|FROM
	|	Catalog.EDAttachedFiles AS AttachedFiles
	|		LEFT JOIN Catalog.EDAttachedFiles AS SlaveBoundFiles
	|		ON (SlaveBoundFiles.ElectronicDocumentOwner = AttachedFiles.Ref)
	|			AND (NOT SlaveBoundFiles.EDKind IN (&TypesOfEDExceptions))
	|WHERE
	|	(AttachedFiles.FileOwner = &OwnerObject
	|			OR AttachedFiles.ElectronicDocumentOwner = &OwnerObject)
	|			AND (NOT AttachedFiles.EDKind IN (&TypesOfEDExceptions))
	|
	|ORDER BY
	|	AttachedFiles.CreationDate";
		
	If ActualED <> Undefined  Then
		Query.Text = StrReplace(Query.Text,
			"AttachedFiles.FileOwner = &ObjectOwner", "AttachedFiles.FileOwner
			| = &ObjectOwner And AttachedFiles.Ref = &ActualED");
		Query.SetParameter("LatestED", ActualED);
	EndIf;
	
	Query.SetParameter("EDKindsList", EDKindsArrayWoodRootElements());
	Query.SetParameter("TypesOfEDExceptions", EDKindsArrayIsNotDisplayedInTree());
	Query.SetParameter("OwnerObject", CurrentDocument);
	Selection = Query.Execute().Select();

	While Selection.Next() Do
		
		EDType = ?(Selection.EDType = Enums.EDVersionElementTypes.SDC,
			Enums.EDVersionElementTypes.RDC,
			Selection.EDType);
		
		SearchParameters = New Structure("EDType, EDKind", EDType, Selection.EDKind);
		
		If Selection.Ref = ActualED Then
			FillTreeRow(ParentalTree, Selection);
			Continue;
		EndIf;
		
		TreeLinesArray = ParentalTree.Rows.FindRows(SearchParameters, False);
		
		If TreeLinesArray.Count() = 0 Then
			// Subordinated ED (TRAD12 purchaser
			// title, Act customer title)clarification notices are being added .
			TreeRow = ParentalTree.Rows.Add();
			FillTreeRow(TreeRow, Selection);
		EndIf;
		
		For Each TreeRow IN TreeLinesArray Do
			FillTreeRow(TreeRow, Selection);
		EndDo;
		
	EndDo;

EndProcedure

&AtServer
Procedure FillTreeRow(TreeRow, Selection)
	
	FillPropertyValues(TreeRow, Selection,
		"Ref, EDStatus, EDStatusChangeDate, EDDirection, Presentation, DeletionMark, EDKind, Version");
	
	ParametersStructure = New Structure;
	If Selection.EDType = Enums.EDVersionElementTypes.PrimaryED
		OR Selection.EDType = Enums.EDVersionElementTypes.ESF Then
		ParametersStructure.Insert("OwnerNumber", Selection.OwnerNumber);
		ParametersStructure.Insert("OwnerDate",  Selection.OwnerDate);
	EndIf;
	ParametersStructure.Insert("EDType",              Selection.EDType);
	TreeRow.Presentation = ElectronicDocumentsService.DetermineEDPresentation(Selection.EDKind, ParametersStructure);
	
	// For incoming ED, relevance is changed manually. IN this case more actual ED need
	// to be highlighted in the list. There is an attribute "BiggerThanActualEDDate"
	// in the tree for this purpose, and also there is an  abject
	// attribute "ActualEDDate" for comparison of the current ED creation date with the date of the actual ED. Necessary to fill them in.
	TreeRow.EDDateMoreActual = False;
	If TreeRow.ActualED Then
		If Not ValueIsFilled(ActualEDDate) AND ValueIsFilled(Selection.Version) Then
			ActualEDDate = Selection.Version;
		EndIf;
	ElsIf ValueIsFilled(ActualEDDate) AND ValueIsFilled(Selection.Version)
		AND ActualEDDate < Selection.Version Then
		TreeRow.EDDateMoreActual = True;
	EndIf;
	
	If Selection.ExistenceOfSubordinateDocuments Then
		
		OutputSubordinateDocuments(Selection.Ref, TreeRow);
		
	EndIf;
	
EndProcedure

//Initiates the output in the tree and displays it after the end of creation.
&AtClient
Procedure DisplayTreeOfED()

	RefreshWoodED();
	ExpandRow();

EndProcedure

&AtServer
Function PackagesToSendingArray(RefED)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PackageEDElectronicDocuments.Ref
	|FROM
	|	Document.EDPackage.ElectronicDocuments AS PackageEDElectronicDocuments
	|WHERE
	|	PackageEDElectronicDocuments.OwnerObject = &OwnerObject
	|	AND PackageEDElectronicDocuments.Ref.PackageStatus = VALUE(Enum.EDPackagesStatuses.PreparedToSending)
	|	AND Not PackageEDElectronicDocuments.Ref.DeletionMark
	|	AND PackageEDElectronicDocuments.ElectronicDocument = &ElectronicDocument
	|
	|ORDER BY
	|	PackageEDElectronicDocuments.Ref.PointInTime DESC";
	Query.SetParameter("OwnerObject", RefED.FileOwner);
	Query.SetParameter("ElectronicDocument", RefED);

	Result = Query.Execute();

	If Result.IsEmpty() Then
		EDKindsArray = New Array;
		EDKindsArray.Add(RefED);
		EDPackagesStructuresArray = ElectronicDocumentsService.CreateEDPackageDocuments(EDKindsArray, True);
	Else
		EDPackagesStructuresArray = New Array;
		EDPackagesStructuresArray.Add(New Structure("EDP", Result.Unload().UnloadColumn("Ref")[0]));
	EndIf;
	
	Return EDPackagesStructuresArray;
	
EndFunction

&AtClient
Procedure TreeSubordinateEDChoice(Item, SelectedRow, Field, StandardProcessing)

	StandardProcessing = False;
	
	If Item.CurrentData <> Undefined Then
		If Field.Name = "TreeSubordinateEDExpectedAction" AND Item.CurrentData.RowIsAvailable Then
			StandardProcessing = False;
			RunningAction = Item.CurrentData.ExpectedAction;
			If RunningAction = PredefinedValue("Enum.EDExpectedAction.Generate") Then
				
				If Item.CurrentData.EDKind = PredefinedValue("Enum.EDKinds.NotificationAboutReception")
					AND Item.CurrentData.GetParent() <> Undefined
					AND ValueIsFilled(Item.CurrentData.GetParent().Ref) Then
					
					EDKindsArrayForNotices = New Array;
					EDKindsArrayForNotices.Add(Item.CurrentData.GetParent().Ref);
					ElectronicDocumentsServiceClient.GenerateSignServiceED(EDKindsArrayForNotices,
						Item.CurrentData.EDKind)
					
				ElsIf (Item.CurrentData.EDType = PredefinedValue("Enum.EDVersionElementTypes.PrimaryED")
					OR Item.CurrentData.EDType = PredefinedValue("Enum.EDVersionElementTypes.ESF"))
					AND Not ValueIsFilled(Item.CurrentData.Ref)
					AND Item.CurrentData.EDDirection = PredefinedValue("Enum.EDDirections.Outgoing") Then
					
					ElectronicDocumentsClient.GenerateNewED(ObjectRef, False);
				EndIf;
				
			ElsIf RunningAction = PredefinedValue("Enum.EDExpectedAction.Approve")
				  OR RunningAction = PredefinedValue("Enum.EDExpectedAction.ApproveSend") Then
				
				If ElectronicDocumentsServiceCallServer.IsRightToProcessED() Then
					ElectronicDocumentsServiceClient.ConfirmED(ObjectRef, Item.CurrentData.Ref, True);
				EndIf;
				
			ElsIf RunningAction = PredefinedValue("Enum.EDExpectedAction.Sign")
				OR RunningAction = PredefinedValue("Enum.EDExpectedAction.SignSend") Then
				
				ElectronicDocumentsClient.GenerateSignSendED(ObjectRef, Item.CurrentData.Ref);
				
			ElsIf RunningAction = PredefinedValue("Enum.EDExpectedAction.Send") Then
				
				EDPackagesStructuresArray = PackagesToSendingArray(Item.CurrentData.Ref);
				If EDPackagesStructuresArray.Count() > 0 Then
					
					ArrayPED = New Array;
					ArrayPED.Add(EDPackagesStructuresArray[0].EDP);
					
					ElectronicDocumentsServiceClient.SendEDPackagesArray(ArrayPED);
				EndIf;
			ElsIf RunningAction = PredefinedValue("Enum.EDExpectedAction.Accept") Then
				ElectronicDocumentsServiceClient.HandleCancellationOffer(Item.CurrentData.GetParent().Ref);
			EndIf;
			
			If ValueIsFilled(Items.TreeSubordinateED.CurrentRow) Then 
				Items.TreeSubordinateED.Expand(Items.TreeSubordinateED.CurrentRow, True);
			EndIf;
			
		Else
			ElectronicDocumentsServiceClient.OpenEDForViewing(Item.CurrentData.Ref);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure TreeSubordinateEDBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	If Item.CurrentItem <> Undefined Then
		
		If Item.CurrentItem.Name = "TreeSubordinateEDPresentation" Then
			
			If Item.CurrentData <> Undefined
				AND TypeOf(Item.CurrentData.Ref) = Type("CatalogRef.EDAttachedFiles")
				AND ValueIsFilled(Item.CurrentData.Ref) Then
				
				ElectronicDocumentsServiceClient.OpenEDForViewing(Item.CurrentData.Ref);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - Form commands actions

&AtClient
Procedure Refresh(Command)
	
	DisplayTreeOfED();
	
EndProcedure

&AtClient
Procedure EventLogMonitor(Command)
	
	FormParameters = New Structure;
	
	Filter = New Structure;
	Filter.Insert("EDOwner", ObjectRef);
	
	FormParameters.Insert("Filter", Filter);
	FormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpenForm("InformationRegister.EDEventsLog.ListForm", FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("InitialDocument", InitialDocument);
	
	Parameters.Property("FilterObject", ObjectRef);
	
	If ValueIsFilled(ObjectRef) Then
		RefreshWoodED();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		DisplayTreeOfED();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ExpandRow();
	
	If ValueIsFilled(InitialDocument) Then
		FindED();
	EndIf;
	
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
