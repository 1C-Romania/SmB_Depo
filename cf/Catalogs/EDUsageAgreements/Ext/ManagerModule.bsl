////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "ListForm"
		Or FormKind = "ChoiceForm" Then
		Return;
	EndIf;
	
	If Parameters.Property("Key") AND ValueIsFilled(Parameters.Key) Then
		
		AgreementAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(Parameters.Key);
		IsIntercompany = AgreementAttributes.IsIntercompany;
		EDExchangeMethod = AgreementAttributes.EDExchangeMethod;
		
	ElsIf Parameters.Property("FillingValues") 
		AND TypeOf(Parameters.FillingValues) = Type("Structure")
		AND Parameters.FillingValues.Property("IsIntercompany")
		AND Parameters.FillingValues.Property("EDExchangeMethod") Then
		
		IsIntercompany = Parameters.FillingValues.IsIntercompany;
		EDExchangeMethod = Parameters.FillingValues.EDExchangeMethod;
		
	ElsIf Parameters.Property("CopyingValue") 
		AND ValueIsFilled(Parameters.CopyingValue)
		AND TypeOf(Parameters.CopyingValue) = Type("CatalogRef.EDUsageAgreements") Then 
		
		AgreementAttributes = ElectronicDocumentsServiceCallServer.EDFSettingAttributes(Parameters.CopyingValue);
		IsIntercompany = AgreementAttributes.IsIntercompany;
		EDExchangeMethod = AgreementAttributes.EDExchangeMethod;
		
	Else
		IsIntercompany = Undefined;
		EDExchangeMethod = Undefined;
	EndIf;
	
	StandardProcessing = False;
	
	SelectedForm = "ItemForm";
	If IsIntercompany = True Then
		SelectedForm = "IntercompanyItemForm";
	ElsIf EDExchangeMethod = PredefinedValue("Enum.EDExchangeMethods.ThroughBankWebSource") Then
		SelectedForm = "ItemFormBank";
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Info base update

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Handler of the update BED 1.0.4.0
// divides TORG12 into TORG12Seller and TORG12Customer, AcceptanceCertificate into ActPerformer and ActCustomer
//
Procedure RefreshDocumentKinds() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.DeletionMark
	|	AND EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)";
	
	Result = Query.Execute().Select();
	
	While Result.Next() Do
		
		AgreementToFind = Result.Ref.GetObject();
		WriteObject = False;
		
		TORG12Seller = AgreementToFind.OutgoingDocuments.Find(Enums.EDKinds.TORG12Seller, "OutgoingDocument");
		
		If TORG12Seller = Undefined Then
			FoundString= AgreementToFind.OutgoingDocuments.Find(Enums.EDKinds.TORG12, "OutgoingDocument");
			If FoundString <> Undefined Then
				NewRow = AgreementToFind.OutgoingDocuments.Append();
				NewRow.OutgoingDocument         = Enums.EDKinds.TORG12Seller;
				NewRow.UseDS           = FoundString.UseDS;
				NewRow.ExpectDeliveryTicket = FoundString.ExpectDeliveryTicket;
				NewRow.ToForm               = FoundString.ToForm;
				WriteObject = True;
			EndIf;
		EndIf;
		
		TORG12Customer = AgreementToFind.OutgoingDocuments.Find(
								Enums.EDKinds.TORG12Customer,
								"OutgoingDocument");
		
		If TORG12Customer = Undefined Then
			FoundString = AgreementToFind.IncomingDocuments.Find(Enums.EDKinds.TORG12, "IncomingDocument");
			If FoundString <> Undefined Then
				NewRow = AgreementToFind.OutgoingDocuments.Append();
				NewRow.OutgoingDocument         = Enums.EDKinds.TORG12Customer;
				NewRow.UseDS           = FoundString.UseDS;
				NewRow.ExpectDeliveryTicket = FoundString.ExpectDeliveryTicket;
				NewRow.ToForm               = FoundString.ToForm;
				WriteObject = True;
			EndIf;
		EndIf;
		
		ActPerformer = AgreementToFind.OutgoingDocuments.Find(Enums.EDKinds.ActPerformer, "OutgoingDocument");
		
		If ActPerformer = Undefined Then
			FoundString = AgreementToFind.OutgoingDocuments.Find(
									Enums.EDKinds.AcceptanceCertificate,
									"OutgoingDocument");
			If FoundString <> Undefined Then
				NewRow = AgreementToFind.OutgoingDocuments.Append();
				NewRow.OutgoingDocument         = Enums.EDKinds.ActPerformer;
				NewRow.UseDS           = FoundString.UseDS;
				NewRow.ExpectDeliveryTicket = FoundString.ExpectDeliveryTicket;
				NewRow.ToForm               = FoundString.ToForm;
				WriteObject = True;
			EndIf;
		EndIf;
		
		ActCustomer = AgreementToFind.OutgoingDocuments.Find(Enums.EDKinds.ActCustomer, "OutgoingDocument");
		
		If ActCustomer = Undefined Then
			FoundString = AgreementToFind.IncomingDocuments.Find(Enums.EDKinds.AcceptanceCertificate,
																		"IncomingDocument");
			If FoundString <> Undefined Then
				NewRow = AgreementToFind.OutgoingDocuments.Append();
				NewRow.OutgoingDocument         = Enums.EDKinds.ActCustomer;
				NewRow.UseDS           = FoundString.UseDS;
				NewRow.ExpectDeliveryTicket = FoundString.ExpectDeliveryTicket;
				NewRow.ToForm               = FoundString.ToForm;
				WriteObject = True;
			EndIf;
		EndIf;
		
		If WriteObject Then
			InfobaseUpdate.WriteObject(AgreementToFind)
		EndIf;
		
	EndDo;
	
EndProcedure

// Handler of the update BED 1.1.6.3
// Executes filling the format version in the tabular section of OutgoingDocuments.
//
Procedure FillFormatsVersions() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.DeletionMark
	|	AND EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)";
	
	Result = Query.Execute().Select();
	
	While Result.Next() Do
		
		AgreementToFind = Result.Ref.GetObject();
		WriteObject = False;
		
		For Each DocumentKind IN AgreementToFind.OutgoingDocuments Do
			If DocumentKind.ToForm AND Not ValueIsFilled(DocumentKind.FormatVersion)
				AND DocumentKind.OutgoingDocument = Enums.EDKinds.ProductsDirectory Then
				
				DocumentKind.FormatVersion = "CML 4.02";
				WriteObject = True;
			EndIf;
		EndDo;
		
		If WriteObject Then
			InfobaseUpdate.WriteObject(AgreementToFind);
		EndIf;
		
	EndDo;
	
EndProcedure

// Handler of the update BED 1.1.7.1 
// Transfers the DS certificate from the attribute of "Certificate of authorization" to the tabular section "CompanySignatureCertificates".
//
Procedure TransferCertificateAuthorizationInTP() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref,
	|	EDUsageAgreements.DeleteSubscriberCertificate
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.DeletionMark
	|	AND EDUsageAgreements.EDExchangeMethod = &EDExchangeMethod";
	
	Query.SetParameter("EDExchangeMethod", Enums.EDExchangeMethods.ThroughEDFOperatorTaxcom);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DSCertificate = Selection.DeleteSubscriberCertificate;
		If ValueIsFilled(DSCertificate) Then
			EDAgreement = Selection.Ref.GetObject();
			NewRow = EDAgreement.CompanySignatureCertificates.Append();
			NewRow.Certificate = DSCertificate;
			EDAgreement.DeleteSubscriberCertificate = Undefined;
			InfobaseUpdate.WriteObject(EDAgreement);
		EndIf;
		
	EndDo;
	
EndProcedure

// Handler of the update BED 1.1.7.4 
// Executes filling the format version in the tabular section of OutgoingDocuments.
//
Procedure FillFormatsVersionsOfOutgoingEDAndPackage() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.DeletionMark
	|	AND (EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|	OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP)
	|	OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail))";
	
	Result = Query.Execute().Select();
	
	While Result.Next() Do
		
		AgreementToFind = Result.Ref.GetObject();
		WriteObject = False;
		
		For Each DocumentKind IN AgreementToFind.OutgoingDocuments Do
			If Not ValueIsFilled(DocumentKind.FormatVersion) Then
				
				FormatVersion = "CML 4.02";
				If DocumentKind.OutgoingDocument = Enums.EDKinds.RandomED Then
					
					FormatVersion = "";
				ElsIf DocumentKind.OutgoingDocument = Enums.EDKinds.ActCustomer
					OR DocumentKind.OutgoingDocument = Enums.EDKinds.ActPerformer
					OR DocumentKind.OutgoingDocument = Enums.EDKinds.TORG12Customer
					OR DocumentKind.OutgoingDocument = Enums.EDKinds.TORG12Seller Then
					
					FormatVersion = "Federal Tax Service 5.01";
				EndIf;
				
				DocumentKind.FormatVersion = FormatVersion;
				WriteObject = True;
			EndIf;
		EndDo;
		
		If Not ValueIsFilled(AgreementToFind.PackageFormatVersion) Then
			AgreementToFind.PackageFormatVersion = Enums.EDPackageFormatVersions.Version10;
		EndIf;
			
		If WriteObject Then
			InfobaseUpdate.WriteObject(AgreementToFind);
		EndIf;
		
	EndDo;
	
EndProcedure

// Handler of the update BED 1.1.13.6
// Executes filling the format version in the tabular section of OutgoingDocuments.
//
Procedure UpdateOutgoingEDIPackFormatsVersions() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	(EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail))";
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		
		AgreementToFind = Result.Ref.GetObject();
		WriteObject = False;
		
		For Each DocumentKind IN AgreementToFind.OutgoingDocuments Do
			If ValueIsFilled(DocumentKind.FormatVersion)
				AND DocumentKind.FormatVersion = "CML 2.06" Then
				
				DocumentKind.FormatVersion = "CML 2.07";
				WriteObject = True;
			EndIf;
		EndDo;
		
		If WriteObject Then
			InfobaseUpdate.WriteObject(AgreementToFind);
		EndIf;
		
	EndDo;

EndProcedure

// Handler of the update BED 1.1.14.2
// Executes filling the attribute "CryptographyIsUsed".
//
Procedure FillCryptographyUsage() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	Not EDUsageAgreements.CryptographyIsUsed
	|	AND EDUsageAgreements.User = """"";
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		EDAgreement = Result.Ref.GetObject();
		EDAgreement.CryptographyIsUsed = True;
		InfobaseUpdate.WriteObject(EDAgreement);
	EndDo;
	
EndProcedure

// Handler of the
// update BED 1.2.2.2 Executes filling the format version in the tabular section of OutgoingDocuments.
//
Procedure UpdateOutgoingED207FormatVersion_208() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EDUsageAgreements.Ref
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	(EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughDirectory)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughFTP)
	|			OR EDUsageAgreements.EDExchangeMethod = VALUE(Enum.EDExchangeMethods.ThroughEMail))";
	
	Result = Query.Execute().Select();
	While Result.Next() Do
		
		AgreementToFind = Result.Ref.GetObject();
		WriteObject = False;
		
		For Each DocumentKind IN AgreementToFind.OutgoingDocuments Do
			If ValueIsFilled(DocumentKind.FormatVersion)
				AND (DocumentKind.FormatVersion = "CML 2.06"
					Or DocumentKind.FormatVersion = "CML 2.07") Then
				
				DocumentKind.FormatVersion = "CML 2.08";
				WriteObject = True;
			EndIf;
		EndDo;
		
		If WriteObject Then
			InfobaseUpdate.WriteObject(AgreementToFind);
		EndIf;
		
	EndDo;

EndProcedure

#EndIf