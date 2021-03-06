Signing
=======

KoreBuild supports generating a signing request manfiest. This includes a list of all files that should be signed
and information about the strongname or certificate that should be used.

## Format

The signing request manifest supports three element types. A minimal example looks like this. See [Elements](#Elements) below for details

```xml
<SigningRequest>
  <File Path="MyAssembly.dll" Certificate="MyCert" StrongName="MyStrongName" />
  <File Path="build/Another.dll" Certificate="MyCert" />
  <Container Path="MyLib.1.0.0.nupkg" Type="nupkg" Certificate="NuGetCert">
    <File Path="lib/netstandard2.0/MyLib.dll" Certificate="MyCert" />
  </Container>
  <Container Path="MyVSTool.vsix" Type="vsix" Certificate="VsixCert">
    <File Path="MyVSTool.dll" Certificate="MyCert" />
    <!-- excluded from signing, but useful if you want to assert all files in a container are accounted for. -->
    <ExcludedFile Path="NotMyLib.dll" />
  </Container>
</SigningRequest>
```

## Config via csproj

KoreBuild can generate the sign request using information from MSBuild projects. The following options can be set.

### Assemblies

To sign assemblies, set the AssemblySigningCertName and AssemblySigningStrongName property in the \*.csproj.

```xml
<PropertyGroup>
  <AssemblySigningCertName>MyCert</AssemblySigningCertName>
  <AssemblySigningStrongName>PrivateStrongName</AssemblySigningStrongName>
</PropertyGroup>
```

This will generate a signing request like this:

```xml
<SigningRequest>
  <File Path="MyLib.dll" Certificate="MyCert" StrongName="PrivateStrongName" />
</SigningRequest>
```

### NuGet packages

To sign NuGet packages, set the PackageSigningCertName property in the \*.csproj that produces the nupkg.

```xml
<PropertyGroup>
  <PackageSigningCertName>NuGetCert</PackageSigningCertName>
</PropertyGroup>
```

This will generate a signing request like this:

```xml
<SigningRequest>
  <Container Path="MyLib.1.0.0.nupkg" Type="nupkg" Certificate="NuGetCert" />
</SigningRequest>
```

### NuGet packages with assemblies

For assemblies that ship in a NuGet package, you can specify multiple properties.

```xml
<PropertyGroup>
  <AssemblySigningCertName>MyCert</AssemblySigningCertName>
  <PackageSigningCertName>NuGetCert</PackageSigningCertName>
</PropertyGroup>
```

This will generate a signing request like this:

```xml
<SigningRequest>
  <Container Path="MyLib.1.0.0.nupkg" Type="nupkg" Certificate="NuGetCert">
    <File Path="lib/netstandard2.0/MyLib.dll" Certificate="MyCert" />
  </Container>
</SigningRequest>
```

### Projects using nuspec

When creating a NuGet package via nuspec + csproj, KoreBuild cannot detect which assemblies
end up in the nuget package. You must explicitly declare which assemblies inside the nupkg
should be signed.

```xml
<PropertyGroup>
  <NuspecFile>MyPackage.nuspec<NuspecFile/>
</PropertyGroup>

<ItemGroup>
  <!-- TargetFileName is a well-known MSBuild property that is set to MyPackage.dll -->
  <SignedPackageFile Include="$(TargetPath)" PackagePath="tools/$(TargetFileName)" Visible="false" />
</ItemGroup>
```

### NuGet packages with signable files

Sometimes other signable assemblies end up in a nupkg. Signing for these file types can be controlled with `SignedPackageFile`, and `ExcludePackageFileFromSigning` items.

```xml
  <ItemGroup>
    <!-- Files that come from other ASP.NET Core projects -->
    <SignedPackageFile Include="$(PublishDir)Microsoft.Extensions.Configuration.Abstractions.dll" Certificate="$(AssemblySigningCertName)" PackagePath="tools/Microsoft.Extensions.Configuration.Abstractions.dll" Visible="false" />

    <!-- Third-party cert -->
    <SignedPackageFile Include="$(PublishDir)Newtonsoft.Json.dll" Certificate="3PartyDual" PackagePath="tools/Newtonsoft.Json.dll" Visible="false" />

    <!-- This should already be signed by the dotnet-core team -->
    <ExcludePackageFileFromSigning Include="$(PublishDir)System.Runtime.CompilerServices.Unsafe.dll" PackagePath="tools/System.Runtime.CompilerServices.Unsafe.dll" Visible="false" />
  </ItemGroup>
```

### Disabling signing

You can disable sign request generation on an MSBuild project by setting DisableCodeSigning.

```xml
<PropertyGroup>
  <DisableCodeSigning>true</DisableCodeSigning>
</PropertyGroup>
```

## Additional signing files

KoreBuild targets may produce additional artifacts that should be signed by methods not detected from MSBuild project files. These files can be added to the sign request by adding
these elements to the `build/repo.props` file. (See also [KoreBuild.md](./KoreBuild.md#repo-props))

```xml
<!-- build/repo.props -->
<ItemGroup>
  <FilesToSign Include="$(ArtifactsDir)libuv.dll" Certificate="3PartyDual" />

  <!-- Files can also be listed as "do not sign", for completeness -->
  <FilesToExcludeFromSigning Include="$(ArtifactsDir)my.test.dll" Certificate="3PartyDual" />
</ItemGroup>
```

## Elements

#### `SigningRequest`

Root element. No options.

#### `File`

A file to be signed.

**Path** - file path, relative to the file path. If nested in a `<Container>`, is relative to the organization within the container

**Certificate** - the name of the certificate to use

**StrongName** - for assemblies only. This is used to strong name assemblies that were delay signed in public.

#### `Container`

A container is an archive file, installer, or some kind of bundle that can be signed, or that has files that can be signed
inside it. Nested elements can be added for `<File>` and `<ExcludedFile>`.

**Path** - file path to the container

**Certificate** - the name of the certificate to use

**Type** - The type of the container. Instructs the consumer how to extract the container. Example values:

  - zip
  - tar.gz
  - vsix
  - nupkg
  - msi

#### `ExcludedFile`

This is useful when you want to exclude files within a container from being signed, but want to assert that
all files in a container are accounted for.

**Path** - file path to a file to be ignored by the signing tool

