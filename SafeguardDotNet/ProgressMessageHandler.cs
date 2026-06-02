// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet;

using System;
using System.IO;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

/// <summary>
/// A <see cref="DelegatingHandler"/> that raises progress events during HTTP send and receive operations.
/// Replaces the <c>System.Net.Http.Handlers.ProgressMessageHandler</c> from Microsoft.AspNet.WebApi.Client.
/// </summary>
internal class ProgressMessageHandler : DelegatingHandler
{
    /// <summary>
    /// Raised periodically as request content bytes are sent.
    /// </summary>
    public event EventHandler<HttpProgressEventArgs> HttpSendProgress;

    /// <summary>
    /// Raised periodically as response content bytes are received.
    /// </summary>
    public event EventHandler<HttpProgressEventArgs> HttpReceiveProgress;

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (HttpSendProgress != null && request.Content != null)
        {
            var totalBytes = request.Content.Headers.ContentLength;
            var originalStream = await request.Content.ReadAsStreamAsync().ConfigureAwait(false);
            var progressStream = new ProgressStream(originalStream, totalBytes, (bytesTransferred, total) =>
                HttpSendProgress?.Invoke(this, new HttpProgressEventArgs(bytesTransferred, total)));
            var streamContent = new StreamContent(progressStream);

            foreach (var header in request.Content.Headers)
            {
                streamContent.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }

            request.Content = streamContent;
        }

        var response = await base.SendAsync(request, cancellationToken).ConfigureAwait(false);

        if (HttpReceiveProgress != null && response.Content != null)
        {
            var totalBytes = response.Content.Headers.ContentLength;
            var originalStream = await response.Content.ReadAsStreamAsync().ConfigureAwait(false);
            var progressStream = new ProgressStream(originalStream, totalBytes, (bytesTransferred, total) =>
                HttpReceiveProgress?.Invoke(this, new HttpProgressEventArgs(bytesTransferred, total)));
            var streamContent = new StreamContent(progressStream);

            foreach (var header in response.Content.Headers)
            {
                streamContent.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }

            response.Content = streamContent;
        }

        return response;
    }

    private sealed class ProgressStream : Stream
    {
        private readonly Stream _innerStream;
        private readonly long? _totalBytes;
        private readonly Action<long, long?> _onProgress;
        private long _bytesRead;

        public ProgressStream(Stream innerStream, long? totalBytes, Action<long, long?> onProgress)
        {
            _innerStream = innerStream;
            _totalBytes = totalBytes;
            _onProgress = onProgress;
        }

        public override bool CanRead => true;

        public override bool CanSeek => _innerStream.CanSeek;

        public override bool CanWrite => false;

        public override long Length => _innerStream.Length;

        public override long Position
        {
            get => _innerStream.Position;
            set => _innerStream.Position = value;
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            var bytesRead = _innerStream.Read(buffer, offset, count);
            if (bytesRead > 0)
            {
                _bytesRead += bytesRead;
                _onProgress(_bytesRead, _totalBytes);
            }

            return bytesRead;
        }

        public override async Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken)
        {
            var bytesRead = await _innerStream.ReadAsync(buffer, offset, count, cancellationToken).ConfigureAwait(false);
            if (bytesRead > 0)
            {
                _bytesRead += bytesRead;
                _onProgress(_bytesRead, _totalBytes);
            }

            return bytesRead;
        }

        public override void Flush() => _innerStream.Flush();

        public override long Seek(long offset, SeekOrigin origin) => _innerStream.Seek(offset, origin);

        public override void SetLength(long value) => _innerStream.SetLength(value);

        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                _innerStream.Dispose();
            }

            base.Dispose(disposing);
        }
    }
}

/// <summary>
/// Event arguments for HTTP progress notifications.
/// </summary>
internal class HttpProgressEventArgs : EventArgs
{
    /// <summary>
    /// Gets the number of bytes transferred so far.
    /// </summary>
    public long BytesTransferred { get; }

    /// <summary>
    /// Gets the total number of bytes expected, or null if unknown.
    /// </summary>
    public long? TotalBytes { get; }

    internal HttpProgressEventArgs(long bytesTransferred, long? totalBytes)
    {
        BytesTransferred = bytesTransferred;
        TotalBytes = totalBytes;
    }
}
