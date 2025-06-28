# Contributing to nginx-conf

Thank you for your interest in contributing to this modern nginx configuration repository!

## How to Contribute

### Reporting Issues
- Use GitHub Issues for bug reports and feature requests
- Include nginx version, OS, and configuration details
- Provide minimal reproduction steps

### Pull Requests
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Test your changes thoroughly
4. Update documentation if needed
5. Submit a pull request with clear description

### Configuration Guidelines

#### Security First
- All configurations must follow security best practices
- Include rate limiting for new endpoints
- Use secure headers and TLS settings
- Document any security implications

#### Performance Considerations
- Test configurations under load
- Optimize for common use cases
- Include caching strategies where appropriate
- Document performance impact

#### Documentation Standards
- Update relevant docs/ files for new features
- Include practical examples
- Explain the "why" not just the "how"
- Test all example commands

### Testing
- Test configurations with `nginx -t`
- Verify SSL/TLS settings with SSL Labs
- Test rate limiting and security headers
- Validate against production scenarios

### Code Style
- Use consistent indentation (4 spaces)
- Comment complex configurations
- Follow existing naming conventions
- Keep configurations modular

## Development Setup

```bash
# Clone your fork
git clone https://github.com/yourusername/nginx-conf.git
cd nginx-conf

# Test configuration syntax
sudo nginx -t -c nginx.conf

# Test specific site configuration
sudo nginx -t -c sites-available/example-site.com.conf
```

## Questions?

Open an issue for questions about contributing or configuration best practices.