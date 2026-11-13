{
  version: 1,
  dependencies: [
    {
      source: {
        git: {
          remote: 'https://github.com/helmetica-framework/alembic',
          subdir: '',
        },
      },
      version: std.extVar('alembic_version'),
    },
  ],
  legacyImports: true,
}
